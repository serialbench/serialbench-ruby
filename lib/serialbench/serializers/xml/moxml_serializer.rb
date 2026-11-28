# frozen_string_literal: true

require_relative 'base_xml_serializer'

module Serialbench
  module Serializers
    module Xml
      # The lutaml unified XML API (moxml) with its preferred default
      # backend (leptris on CRuby). Prices the abstraction layer
      # against the direct leptris binding rows.
      class MoxmlSerializer < BaseXmlSerializer
        def name
          'moxml'
        end

        def parse(xml_string)
          require 'moxml'
          Moxml.new.parse(xml_string)
        end

        def generate(data, _options = {})
          require 'moxml'
          return data.to_xml if data.respond_to?(:to_xml)

          # hash payload: emit the sibling adapters' simple key/value
          # document as XML text — moxml's mutation API varies by the
          # resolved adapter (the nokogiri fallback lacks add_element)
          require 'cgi'
          body = data.map do |key, value|
            "<#{key}>#{CGI.escapeHTML(value.to_s)}</#{key}>"
          end.join
          "<r>#{body}</r>"
        end

        def capabilities
          super | Set.new(%i[xpath])
        end

        def xpath_query(document, expression)
          document.xpath(expression).size
        end

        def available?
          return @available if defined?(@available)

          @available = begin
            require 'moxml'
            Moxml.new.parse('<probe/>')
            true
          rescue StandardError, LoadError => e
            warn "#{name} unavailable: #{e.class}: #{e.message}"
            false
          end
        end

        def version
          return 'unknown' unless available?

          require 'moxml'
          Gem.loaded_specs['moxml'].version.to_s
        end

        def library_require_name
          'moxml'
        end
      end
    end
  end
end
