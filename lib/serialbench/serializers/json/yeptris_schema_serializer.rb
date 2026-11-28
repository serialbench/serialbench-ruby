# frozen_string_literal: true

require_relative 'base_json_serializer'

module Serialbench
  module Serializers
    module Json
      # Yeptris JSON Schema validation pricing: one compiled schema per
      # canonical shape (config/users/dataset), then validate the raw
      # bytes per iteration — the py/C contract (parse inside).
      class YeptrisSchemaSerializer < BaseJsonSerializer
        def name
          'yeptris-schema'
        end

        def capabilities
          Set.new(%i[validation])
        end

        def available?
          return @available if defined?(@available)

          @available = begin
            require 'yeptris'
            require 'yeptris/validation'
            Yeptris::Validation::Schema.compile('{"type":"object"}')
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

        def validate(json_string, _schema)
          require 'yeptris'
          require 'yeptris/validation'

          stem = json_string.include?('"users"') ? 'users' : json_string.include?('"dataset"') ? 'dataset' : 'config'
          schema = schemas[stem] ||= begin
            path = File.join('test_data', "#{stem}.schema.json")
            raise "missing #{path}" unless File.exist?(path)

            Yeptris::Validation::Schema.compile(File.read(path))
          end
          schema.valid?(json_string)
        end

        private

        def schemas
          @schemas ||= {}
        end
      end
    end
  end
end
