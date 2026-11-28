# frozen_string_literal: true

require_relative 'base_yaml_serializer'

module Serialbench
  module Serializers
    module Yaml
      class YeptrisSerializer < BaseYamlSerializer
        def name
          'yeptris-yaml'
        end

        def parse(yaml_string)
          require 'yeptris'
          Yeptris::YAML.load(yaml_string)
        end

        def generate(object, _options = {})
          require 'yeptris'
          Yeptris::YAML.dump(object)
        end

        def stream_parse(yaml_string, &block)
          require 'yeptris'
          Yeptris::YAML.load_stream(yaml_string).each { |doc| block.call(:document, doc) }
        end

        def capabilities
          super | Set.new(%i[streaming plan])
        end

        # Query-plan walk (Descriptor materialization): the plan parses
        # the document itself, so plan_walk takes the raw YAML string.
        # The per-size descriptor follows the root key (config/users/
        # dataset); the canonical yaml keys are symbol-style (":host"),
        # mirroring the js wasm face's specs.
        def plan_walk(yaml_string)
          require 'yeptris'
          require 'yeptris/yaml'
          require 'yeptris/yaml/descriptor'

          stem = plan_stem(yaml_string)
          descriptor = plan_descriptors[stem] ||= build_plan_descriptor(stem)
          result = descriptor.walk(yaml_string)
          Array.new(result.rows) { |i| result.at(i) }
        end

        def plan_stem(yaml_string)
          if yaml_string.include?(':users')
            'users'
          elsif yaml_string.include?(':dataset')
            'dataset'
          else
            'config'
          end
        end

        def plan_descriptors
          @plan_descriptors ||= {}
        end

        def build_plan_descriptor(stem)
          require 'yeptris'
          require 'yeptris/yaml/descriptor'

          case stem
          when 'users'
            ::Yeptris::YAML::Descriptor.build(
              kind: :seq, path: [':users'],
              children: %w[id name email created_at].map do |f|
                { name: ":#{f}", kind: (f == 'id' ? :int : :str) }
              end
            )
          when 'dataset'
            ::Yeptris::YAML::Descriptor.build(
              kind: :map, path: [':dataset', ':records'],
              children: [{ name: ':id', kind: :int }, { name: ':timestamp', kind: :str }]
            )
          else
            ::Yeptris::YAML::Descriptor.build(
              kind: :map, path: [':config', ':database'],
              children: %w[host port name user password].map do |f|
                { name: ":#{f}", kind: (f == 'port' ? :int : :str) }
              end
            )
          end
        end

        def available?
          return @available if defined?(@available)

          @available = begin
            require 'yeptris'
            Yeptris::YAML.load('probe: true')
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
