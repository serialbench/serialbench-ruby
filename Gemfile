# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

# Platform-specific dependencies
# nokogiri and libxml-ruby fail to compile on Windows ARM due to libxml2
# compilation issues, but work on other platforms
unless Gem.win_platform? && RUBY_PLATFORM.include?('aarch64')
  gem 'nokogiri'
  gem 'libxml-ruby'
end

gem 'leptris', '1.9.385.0'  # parse_html defaults :html4 (nokogiri-parity); :whatwg priced separately; 1.9.44x carries XSD/Schematron/diff/C14N (ruby#676)
gem 'yeptris', '0.6.48.0'   # JSON + CBOR load/dump; faces load standalone (#300); 0.6.7x carries the #739 write-path campaign
gem 'teptris', '0.3.9.1'   # 0.3.3x line; schema validation exposed (compile_schema/schema_validate)
gem 'cbor'                  # RFC 7049 CBOR codec
gem 'benchmark'  # Removed from stdlib in Ruby 4.0
gem 'base64'  # Required for Ruby 3.4+
gem 'lutaml-model', '~> 0.8'
gem 'moxml'                 # lutaml unified XML API; prices the abstraction layer over its default leptris backend
gem 'octokit'
gem 'rake'
gem 'rspec'
gem 'rubocop'
gem 'rubocop-performance'
gem 'rubocop-rspec'
