# frozen_string_literal: true

require_relative 'base_html_serializer'

module Serialbench
  module Serializers
    module Html
      class LeptrisSerializer < BaseHtmlSerializer
        def name
          'leptris'
        end

        # 1.9.201 defaults parse_html to the :html4 engine — the
        # libxml2/Nokogiri-compatible shape. The conformant engine is
        # benchmarked separately as leptris-whatwg.
        def capabilities
          super | Set.new(%i[xpath])
        end

        def parse(html_string)
          require 'leptris'
          require 'leptris/xml'
          Leptris::XML.parse_html(html_string)
        end

        def xpath_query(document, expression)
          document.xpath(expression).size
        end

        def serialize_document(document)
          document.to_xml
        end

        def available?
          return @available if defined?(@available)

          @available = begin
            require 'leptris'
            require 'leptris/xml'
            Leptris::XML.parse_html('<p>probe</p>')
            true
          rescue StandardError, LoadError => e
            warn "#{name} unavailable: #{e.class}: #{e.message}"
            false
          end
        end

        def version
          return 'unknown' unless available?

          require 'leptris'
          Leptris::VERSION
        end

        def library_require_name
          'leptris'
        end
      end
    end
  end
end
