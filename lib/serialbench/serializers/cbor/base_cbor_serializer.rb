# frozen_string_literal: true

require_relative '../base_serializer'

module Serialbench
  module Serializers
    module Cbor
      class BaseCborSerializer < BaseSerializer
        def self.format
          :cbor
        end

        def features
          {
            streaming: supports?(:streaming),
            canonical: supports?(:canonical)
          }
        end

        def library_require_name
          raise NotImplementedError, 'Subclasses must implement #library_require_name'
        end

        def available?
          return @available if defined?(@available)

          @available = begin
            require library_require_name
            true
          rescue LoadError
            false
          end
        end
      end
    end
  end
end
