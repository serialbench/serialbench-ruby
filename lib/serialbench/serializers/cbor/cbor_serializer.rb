# frozen_string_literal: true

require_relative 'base_cbor_serializer'

module Serialbench
  module Serializers
    module Cbor
      # The `cbor` gem (RFC 7049 codec, to_cbor/CBOR.load)
      class CborSerializer < BaseCborSerializer
        def name
          'cbor'
        end

        def parse(cbor_bytes)
          require 'cbor'
          CBOR.load(cbor_bytes)
        end

        def generate(object, _options = {})
          require 'cbor'
          object.to_cbor
        end

        def version
          return 'unknown' unless available?

          require 'cbor'
          Gem.loaded_specs['cbor']&.version.to_s
        end

        def library_require_name
          'cbor'
        end
      end
    end
  end
end
