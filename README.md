## ACME R53 Cli

[![Gem Version](https://badge.fury.io/rb/acme-r53-cli.svg)](https://badge.fury.io/rb/acme-r53-cli)

A tool to sign TLS certificates using Let's Encrypt using Acme v02 with DNS-01 challenge.

## Usage

```bash
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
  --ec                       Use EC private keys

```

## Contributing

Submit a PR.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
