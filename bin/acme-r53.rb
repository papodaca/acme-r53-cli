#!/usr/bin/env ruby

require "openssl"

require "docopt"
require "acme-client"
require "aws-sdk-route53"

require "acme-cli/version"

doc = <<DOCOPT
acme-r53.rb

Usage:
  acme-r53.rb sign [options] <domain_name> [<alt_name>...]
  acme-r53.rb register [options] --email <email> [--agree-terms]
  acme-r53.rb -h | --help
  acme-r53.rb -v | --version

Options:
  -h --help                  Show this message
  -v --version               Show the version
  --account <account.pem>    Provide existing account key
  --domain <domain.pem>      Provide domain private key
  --staging                  Use LE Staging directory

DOCOPT

def load_key(passed_in, passed_in_path, default_path)
  if passed_in
    STDERR.puts "Loading #{passed_in_path}"
    if !File.file?(passed_in_path)
      STDERR.puts "[Error]: Cannot load #{passed_in_path}"
      exit 1
    end
    OpenSSL::PKey::RSA.new(File.read(passed_in_path))
  else
    if File.file?(default_path)
      STDERR.puts "Loading #{default_path}"
      OpenSSL::PKey::RSA.new(File.read(default_path))
    else
      STDERR.puts "Creating key #{default_path}"
      key = OpenSSL::PKey::RSA.new(4096)
      File.write(default_path, key)
      key
    end
  end
end

def get_test_name(entry, challenge)
  if entry.include?("*")
    "#{challenge.record_name}.#{entry.gsub("*.", "")}"
  else
    "#{challenge.record_name}.#{entry}"
  end
end

def get_csr_names(identifier)
  if identifier.include?("*")
    [
      identifier
    ]
  else
    [
      identifier
    ]
  end
end

def get_zone_name(record)
  parts = record.split(/\./)
  parts.slice(parts.length - 2, parts.length - 1).join(".") + "."
end

def update_dns(entry, challenge)
  r53 = Aws::Route53::Client.new
  top_domain = get_zone_name(entry)
  zone = r53.list_hosted_zones.hosted_zones.select do |zone|
    zone.name == top_domain
  end.first

  record = get_test_name(entry, challenge)

  change = r53.change_resource_record_sets({
    change_batch: {
      changes: [{
        action: "CREATE",
        resource_record_set: {
          resource_records: [
            {
              value: "\"#{challenge.record_content}\"",
            },
          ],
          name: record,
          ttl: 10,
          type: challenge.record_type
        }
      }]
    },
    hosted_zone_id: zone.id
  })

  r53.wait_until(:resource_record_sets_changed, id: change.change_info.id)

  [zone.id, record, challenge.record_type, challenge.record_content]
end

def delete_dns_record(zone_id, record, type, value)
  r53 = Aws::Route53::Client.new

  r53.change_resource_record_sets({
    change_batch: {
      changes: [{
        action: "DELETE",
        resource_record_set: {
          resource_records: [
            {
              value: "\"#{value}\"",
            },
          ],
          name: record,
          ttl: 10,
          type: type
        }
      }]
    },
    hosted_zone_id: zone_id
  })
end

options = nil

begin
  options = Docopt::docopt(doc)
rescue Docopt::Exit => e
  STDERR.puts e.message
end

exit 1 if options == nil

if options["--version"]
  STDERR.puts AcmeCli::Version::VERSION
  exit 0
end

## Load account key, or create on if missing
account_key = load_key(
  !!options["--account"],
  options["--account"],
  "./account.pem"
)

directory = if options["--staging"]
  "https://acme-staging-v02.api.letsencrypt.org/directory"
else
  "https://acme-v02.api.letsencrypt.org/directory"
end

client = Acme::Client.new(
  private_key: account_key,
  directory: directory
)

if options["register"]
  account = client.new_account(
    contact: "mailto:#{options["<email>"]}",
    terms_of_service_agreed: options["--agree-terms"]
  )
  STDERR.puts "Created account #{account.kid}"
elsif options["sign"]
  identifiers = if options["<alt_name>"]
    options["<alt_name>"].unshift(options["<domain_name>"])
  else
    [options["<domain_name>"]]
  end
  STDERR.puts "Creating order for: #{identifiers.join(", ")}"
  order = client.new_order(identifiers: identifiers)

  order.authorizations.each_with_index do |auth, idx|
    challenge = auth.dns

    STDERR.puts "Creating dns record for: #{identifiers[idx]}"
    record_created = update_dns(identifiers[idx], challenge)

    STDERR.puts "Validating dns record: #{identifiers[idx]}"
    challenge.request_validation
    while challenge.status == 'pending'
      sleep(2)
      challenge.reload
    end

    STDERR.puts "Validated dns record: #{identifiers[idx]}" if challenge.status == "valid"

    STDERR.puts "Delete dns record for: #{identifiers.first}"
    delete_dns_record(*record_created)

    if challenge.status != 'valid'
      STDERR.puts "failed challenge for #{identifiers[idx]}: #{challenge.status}"
      exit 1
    end
  end

  domain_key = load_key(
    !!options["--domain"],
    options["--domain"],
    "./domain.pem"
  )

  STDERR.puts "Signing cert for: #{identifiers.join(", ")}"

  csr = Acme::Client::CertificateRequest.new(
    private_key: domain_key,
    common_name: identifiers.first,
    names: identifiers[1..-1]
  )
  order.finalize(csr: csr)
  sleep(1) while order.status == 'processing'

  puts order.certificate
end
