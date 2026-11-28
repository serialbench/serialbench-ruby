# frozen_string_literal: true

require_relative 'base_xml_serializer'

module Serialbench
  module Serializers
    module Xml
      class LeptrisSerializer < BaseXmlSerializer
        def name
          'leptris'
        end

        def parse(xml_string)
          require 'leptris'
          require 'leptris/xml'
          Leptris::XML.parse(xml_string)
        end

        def generate(data)
          require 'leptris'
          require 'leptris/xml'
          if data.is_a?(Leptris::XML::Document) || data.is_a?(Leptris::XML::Node)
            data.to_xml(indent: 2)
          else
            build_document_from_data(data).to_xml(indent: 2)
          end
        end

        def parse_streaming(xml_string, &block)
          require 'leptris'
          require 'leptris/xml'

          handler = StreamingHandler.new(&block)
          parser = Leptris::XML::SAX::Parser.new(handler)
          parser.parse_memory(xml_string)
          handler.elements_processed
        end

        def capabilities
          super | Set.new(%i[xpath xquery xslt xslt30 validation sax stax c14n diff plan])
        end

        def c14n(document)
          require 'leptris'
          require 'leptris/xml'
          document.canonicalize
        end

        def diff(before, after)
          require 'leptris'
          require 'leptris/xml'
          Leptris::XML.diff(before, after, ignore_ws: true)
        end

        # Query-plan walk (Descriptor materialization): the per-size
        # descriptor follows the document root (config/users/dataset)
        # and is compiled once per stem, mirroring the C harness.
        def plan_walk(xml_string)
          require 'leptris'
          require 'leptris/xml'

          document = parse(xml_string)
          descriptor = descriptors[document.root.name] ||= build_descriptor(document.root.name)
          descriptor.walk(document.root).to_ruby
        end

        def build_descriptor(stem)
          require 'leptris'
          require 'leptris/xml'

          case stem
          when 'config'
            Leptris::XML::Descriptor.build(
              name: 'config',
              children: [
                { name: 'database', kind: :nested, plan: {
                  name: 'database',
                  children: %w[host port name user password].map do |f|
                    { name: f, kind: :scalar }
                  end
                } },
                { name: 'cache', kind: :nested, plan: {
                  name: 'cache',
                  children: [{ name: 'enabled', kind: :scalar }, { name: 'ttl', kind: :scalar }]
                } }
              ]
            )
          when 'users'
            Leptris::XML::Descriptor.build(
              name: 'users',
              children: [{
                name: 'user', kind: :nested, plan: {
                  name: 'user',
                  attributes: [{ name: 'id', kind: :scalar }],
                  children: [
                    { name: 'name', kind: :scalar },
                    { name: 'email', kind: :scalar },
                    { name: 'created_at', kind: :scalar },
                    { name: 'profile', kind: :nested, plan: {
                      name: 'profile',
                      children: [
                        { name: 'age', kind: :scalar },
                        { name: 'city', kind: :scalar },
                        { name: 'preferences', kind: :nested, plan: {
                          name: 'preferences',
                          children: [
                            { name: 'theme', kind: :scalar },
                            { name: 'notifications', kind: :scalar }
                          ]
                        } }
                      ]
                    } }
                  ]
                }
              }]
            )
          else
            Leptris::XML::Descriptor.build(
              name: 'dataset',
              children: [
                { name: 'header', kind: :nested, plan: {
                  name: 'header',
                  children: %w[created count format].map do |f|
                    { name: f, kind: :scalar }
                  end
                } },
                { name: 'records', kind: :nested, plan: {
                  name: 'record',
                  attributes: [{ name: 'id', kind: :scalar }],
                  children: [
                    { name: 'timestamp', kind: :scalar },
                    { name: 'data', kind: :nested, plan: {
                      name: 'data',
                      children: %w[field1 field2 field3].map do |f|
                        { name: f, kind: :scalar }
                      end
                    } },
                    { name: 'metadata', kind: :nested, plan: {
                      name: 'metadata',
                      children: %w[source version checksum].map do |f|
                        { name: f, kind: :scalar }
                      end
                    } }
                  ]
                } }
              ]
            )
          end
        end

        def descriptors
          @descriptors ||= {}
        end

        def xquery_eval(document, expression)
          require 'leptris'
          require 'leptris/xml'
          result = Leptris::XML::XQuery.parse(expression).eval(document)
          result.respond_to?(:length) ? result.length : 1
        end

        def xslt_transform(document, stylesheet)
          require 'leptris'
          require 'leptris/xml'
          Leptris::XML::XSLT.parse(stylesheet).apply_to(document).serialize
        end

        def validate(document, schema)
          require 'leptris'
          require 'leptris/xml'
          Leptris::XML::RelaxNG.parse(schema).valid?(document)
        end

        def xpath_query(document, expression)
          require 'leptris'
          require 'leptris/xml'
          result = document.xpath(expression)
          result.size
        end

        # leptris-ruby >= 1.6 exposes Leptris::XML::Pull, a StAX-style
        # cursor (one event per #next). Declared by gem version so the
        # check never triggers the FFI library load.


        def version
          return 'unknown' unless available?

          require 'leptris'
          require 'leptris/xml'
          Leptris::VERSION
        end

        def library_require_name
          'leptris'
        end

        # The gem's require succeeds even when the libtaurus shared library is
        # missing -- the FFI load happens lazily at first use. Probe with a
        # real parse so "available" means "actually usable".
        def available?
          return @available if defined?(@available)

          @available = begin
            require 'leptris'
          require 'leptris/xml'
            Leptris::XML.parse('<probe/>')
            true
          rescue StandardError, LoadError => e
            warn "#{name} unavailable: #{e.class}: #{e.message}"
            false
          end
        end

        private

        def build_document_from_data(data, root_name = 'root')
          document = Leptris::XML.parse('<root/>')
          document.root.name = sanitize_element_name(root_name)
          append_data(document.root, data)
          document
        end

        def append_data(element, data)
          case data
          when Hash
            data.each do |key, value|
              child = element.document.create_element(sanitize_element_name(key.to_s))
              element.add_child(child)
              append_data(child, value)
            end
          when Array
            data.each do |item|
              child = element.document.create_element('item')
              element.add_child(child)
              append_data(child, item)
            end
          else
            element.content = data.to_s
          end
        end

        def sanitize_element_name(name)
          sanitized = name.to_s.gsub(/[^a-zA-Z0-9_]/, '_')
          sanitized = "element_#{sanitized}" if sanitized.empty? || sanitized =~ /\A\d/
          sanitized
        end

        # SAX handler counting elements, mirroring the Nokogiri adapter's
        # StreamingHandler shape (Leptris SAX delivers attrs as [name, value]
        # pairs, same as Nokogiri::XML::SAX). Plain duck-typed class --
        # Leptris::XML::SAX::Parser needs no base class, and subclassing it
        # would trigger the FFI library load at file-load time.
        class StreamingHandler
          attr_reader :elements_processed

          def initialize(&block)
            @block = block
            @elements_processed = 0
            @element_stack = []
          end

          # No-op callbacks the parser invokes unconditionally (the base
          # Leptris::XML::SAX::Document normally provides these).
          def start_document; end
          def end_document; end
          def xmldecl(_version, _encoding, _standalone); end
          def comment(_string); end
          def processing_instruction(_name, _content); end
          def start_prefix_mapping(_prefix, _uri); end
          def end_prefix_mapping(_prefix); end
          def warning(_string); end
          def error(_message, _line = 0, _column = 0); end

          def start_element(name, attrs = [])
            @elements_processed += 1
            @element_stack.push({ name: name, attributes: Hash[attrs], children: [], text: '' })
          end

          def end_element(_name)
            element = @element_stack.pop
            if @element_stack.empty?
              @block&.call(element)
            else
              @element_stack.last[:children] << element
            end
          end

          def characters(string)
            return if string.strip.empty?

            @element_stack.last[:text] += string if @element_stack.any?
          end

          def cdata_block(string)
            @element_stack.last[:text] += string if @element_stack.any?
          end
        end
      end
    end
  end
end
