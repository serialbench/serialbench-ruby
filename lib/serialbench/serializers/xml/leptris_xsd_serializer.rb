# frozen_string_literal: true

require_relative 'leptris_serializer'

module Serialbench
  module Serializers
    module Xml
      # XSD validation pricing. The schema kind rides the adapter so the
      # validation op stays one vocabulary entry; the per-size schema
      # follows the document root (config/users/dataset — the canonical
      # shapes), compiled once per stem and reused across documents.
      class LeptrisXsdSerializer < LeptrisSerializer
        def name
          'leptris-xsd'
        end

        def capabilities
          Set.new(%i[validation])
        end

        def validate(document, _schema)
          require 'leptris'
          require 'leptris/xml'

          schema = schemas[document.root.name] ||= begin
            path = File.join('test_data', "#{document.root.name}.xsd")
            raise "missing #{path}" unless File.exist?(path)

            Leptris::XML::XSD.compile_file(path)
          end
          schema.valid?(document)
        end

        private

        def schemas
          @schemas ||= {}
        end
      end
    end
  end
end
