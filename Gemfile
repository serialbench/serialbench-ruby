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

gem 'leptris', '1.9.385.0'  # DOWNGRADE 2026-11-29: 1.9.44x leaks native memory per op on the xml leg and OOM-kills every non-mac-intel runner (leptris#2246); all faces the harness uses exist on 1.9.385
gem 'yeptris', '0.6.79.0'   # JSON + CBOR load/dump; faces load standalone (#300); 0.6.7x carries the #739 write-path campaign
gem 'teptris', '0.3.33.1'   # 0.3.3x line; schema validation exposed (compile_schema/schema_validate)
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
