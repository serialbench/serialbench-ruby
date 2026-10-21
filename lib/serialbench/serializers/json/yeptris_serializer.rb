# frozen_string_literal: true

require_relative 'base_json_serializer'

module Serialbench
  module Serializers
    module Json
      # Yeptris JSON side: 0.2.x was parse-only; 0.6.x ships a native
      # dump that round-trips the canonical fixtures exactly.
      class YeptrisSerializer < BaseJsonSerializer
        def name
          'yeptris-json'
        end

        def parse(json_string)
          require 'yeptris'
          Yeptris::JSON.load(json_string)
        end

        def generate(object, _options = {})
          require 'yeptris'
          Yeptris::JSON.dump(object)
        end

        def capabilities
          Set.new(%i[dom parse generate])
        end

        def available?
          return @available if defined?(@available)

          @available = begin
            require 'yeptris'
            Yeptris::JSON.load('{"probe":true}')
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
