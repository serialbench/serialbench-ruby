# frozen_string_literal: true

require_relative 'base_cbor_serializer'

module Serialbench
  module Serializers
    module Cbor
      # Yeptris CBOR side: load + dump. dump round-trips the canonical
      # fixtures exactly as of 0.6.35.1 (yeptris-ruby#293 — before that,
      # strings shaped like exponent notation encoded as floats; before
      # 0.6.34, dump segfaulted outright, yeptris-ruby#152).
      class YeptrisSerializer < BaseCborSerializer
        def name
          'yeptris-cbor'
        end

        def parse(cbor_bytes)
          require 'yeptris'
          require 'yeptris/cbor'
          Yeptris::CBOR.load(cbor_bytes)
        end

        def generate(object, _options = {})
          require 'yeptris'
          require 'yeptris/cbor'
          Yeptris::CBOR.dump(object)
        end

        def capabilities
          Set.new(%i[dom parse generate])
        end

        def available?
          return @available if defined?(@available)

          @available = begin
            # yeptris/cbor assumes the bootstrap ('yeptris' defines
            # Yeptris::Error) — requiring the submodule alone raises
            # NameError, so always load the parent first.
            require 'yeptris'
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
