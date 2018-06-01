
require_relative "lib/acme-cli/version"

Gem::Specification.new do |s|
  s.name          = 'acme-cli'
  s.version       = AcmeCli::Version::VERSION
  s.date          = '2018-05-31'
  s.summary       = "A cli interface for ACMEv2 DNS challenges with Route53"
  s.description   = "A cli interface for ACMEv2 DNS challenges with Route53"
  s.authors       = ["Ethan Apocaca"]
  s.email         = 'papodaca@gmail.com'
  s.files         = ["bin/acme.rb", "lib/**"]
  s.executables   = ["bin/acme.rb"]
  s.require_paths = ["lib"]
  s.homepage      =
    'https://github.com/papodaca/acme-cli'
  s.license       = 'MIT'

  s.add_runtime_dependency("docopt",           "~> 0.6")
  s.add_runtime_dependency("aws-sdk-route53",  "~> 1.9")
  s.add_runtime_dependency("acme-client",      "~> 2.0")

end
