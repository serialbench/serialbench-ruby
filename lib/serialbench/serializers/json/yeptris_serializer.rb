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
          Set.new(%i[dom parse generate plan])
        end

        # Query-plan walk (Descriptor materialization): the plan parses
        # the document itself, so plan_walk takes the raw JSON string.
        # The per-size descriptor follows the root key (config/users/
        # dataset) and is compiled once per stem, mirroring the C harness.
        def plan_walk(json_string)
          require 'yeptris'
          require 'yeptris/json'
          require 'yeptris/json/descriptor'

          stem = plan_stem(json_string)
          descriptor = plan_descriptors[stem] ||= build_plan_descriptor(stem)
          result = descriptor.walk(json_string)
          Array.new(result.rows) { |i| result.at(i) }
        end

        def plan_stem(json_string)
          if json_string.include?('"users"')
            'users'
          elsif json_string.include?('"dataset"')
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
          require 'yeptris/json/descriptor'

          case stem
          when 'users'
            ::Yeptris::JSON::Descriptor.build(
              kind: :seq, path: %w[users],
              children: %w[id name email created_at].map do |f|
                { name: f, kind: (f == 'id' ? :int : :str) }
              end
            )
          when 'dataset'
            ::Yeptris::JSON::Descriptor.build(
              kind: :map, path: %w[dataset records],
              children: [{ name: 'id', kind: :int }, { name: 'timestamp', kind: :str }]
            )
          else
            ::Yeptris::JSON::Descriptor.build(
              kind: :map, path: %w[config database],
              children: %w[host port name user password].map do |f|
                { name: f, kind: (f == 'port' ? :int : :str) }
              end
            )
          end
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
