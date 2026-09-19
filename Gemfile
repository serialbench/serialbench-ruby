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

gem 'leptris', '1.9.201.2'  # parse_html defaults :html4 (nokogiri-parity); :whatwg priced separately
gem 'yeptris', '0.6.7.5'    # CBOR load/dump (dump segfaults on FFI ladder, yeptris-ruby#152)
gem 'teptris', '0.2.36'     # full platform matrix incl. mingw - windows coverage unblocked
gem 'cbor'                  # RFC 7049 CBOR codec
gem 'benchmark'  # Removed from stdlib in Ruby 4.0
gem 'base64'  # Required for Ruby 3.4+
gem 'lutaml-model', '~> 0.7'
gem 'octokit'
gem 'rake'
gem 'rspec'
gem 'rubocop'
gem 'rubocop-performance'
gem 'rubocop-rspec'
