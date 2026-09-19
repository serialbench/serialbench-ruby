# frozen_string_literal: true

require_relative 'base_cbor_serializer'

module Serialbench
  module Serializers
    module Cbor
      # Yeptris CBOR side: decode only — dump segfaults on arrays of >10
      # depth-3 items via the FFI ladder (yeptris-ruby#152), so :generate
      # stays out of the capability set until that ships fixed.
      class YeptrisSerializer < BaseCborSerializer
        def name
          'yeptris-cbor'
        end

        def parse(cbor_bytes)
          require 'yeptris/cbor'
          Yeptris::CBOR.load(cbor_bytes)
        end

        def capabilities
          Set.new(%i[dom parse])
        end

        def available?
          return @available if defined?(@available)

          @available = begin
            require 'yeptris/cbor'
            raise LoadError, 'libyeptris has no CBOR support' unless Yeptris::CBOR.available?

            Yeptris::CBOR.load("\xf5")
            true
          rescue StandardError, LoadError => e
            warn "#{name} unavailable: #{e.class}: #{e.message}"
            false
          end
        end

        def version
          return 'unknown' unless available?

          require 'yeptris'
          Yeptris::VERSION
        end

        def library_require_name
          'yeptris'
        end
      end
    end
  end
end
