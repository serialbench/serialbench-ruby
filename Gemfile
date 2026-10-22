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

gem 'leptris', '1.9.380.1'  # parse_html defaults :html4 (nokogiri-parity); :whatwg priced separately
gem 'yeptris', '0.6.36.0'   # JSON + CBOR load/dump; faces load standalone (#300, fixed 0.6.35.2)
gem 'teptris', '0.3.6.3'    # 0.3.x line (native-doc API); Teptris::TOML.load/dump unchanged
gem 'cbor'                  # RFC 7049 CBOR codec
gem 'benchmark'  # Removed from stdlib in Ruby 4.0
gem 'base64'  # Required for Ruby 3.4+
gem 'lutaml-model', '~> 0.8'
gem 'octokit'
gem 'rake'
gem 'rspec'
gem 'rubocop'
gem 'rubocop-performance'
gem 'rubocop-rspec'
