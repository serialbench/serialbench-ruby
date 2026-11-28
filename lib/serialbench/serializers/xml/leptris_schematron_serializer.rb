# frozen_string_literal: true

require_relative 'leptris_serializer'

module Serialbench
  module Serializers
    module Xml
      # ISO Schematron validation pricing (SVRL-producing validate; the
      # boolean valid? keeps the op comparable). Per-size schema follows
      # the document root, parsed once per stem.
      class LeptrisSchematronSerializer < LeptrisSerializer
        def name
          'leptris-schematron'
        end

        def capabilities
          Set.new(%i[validation])
        end

        def validate(xml_string, _schema)
          require 'leptris'
          require 'leptris/xml'

          stem = xml_string.include?('<users') ? 'users' : xml_string.include?('<dataset') ? 'dataset' : 'config'
          document = parse(xml_string)
          schema = schemas[stem] ||= begin
            path = File.join('test_data', "#{stem}.sch")
            raise "missing #{path}" unless File.exist?(path)

            Leptris::XML::Schematron.parse_file(path)
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
