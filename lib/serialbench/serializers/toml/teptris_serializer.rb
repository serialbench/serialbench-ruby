# frozen_string_literal: true

require_relative 'base_toml_serializer'

module Serialbench
  module Serializers
    module Toml
      class TeptrisSerializer < BaseTomlSerializer
        def name
          'teptris'
        end

        def capabilities
          super | Set.new(%i[plan])
        end

        def parse(toml_string)
          require 'teptris'
          Teptris::TOML.load(toml_string)
        end

        def generate(object, _options = {})
          require 'teptris'
          Teptris::TOML.dump(object)
        end

        def available?
          return @available if defined?(@available)

          @available = begin
            require 'teptris'
            Teptris::TOML.load("probe = true\n")
            true
          rescue StandardError, LoadError => e
            warn "#{name} unavailable: #{e.class}: #{e.message}"
            false
          end
        end

        def version
          return 'unknown' unless available?

          require 'teptris'
          Teptris::VERSION
        end

        # Query-plan walk (Descriptor materialization): the plan parses
        # the document itself, so plan_walk takes the raw TOML string.
        # The per-size descriptor follows the root key (config/users/
        # dataset), mirroring the py adapter's specs; :nested spans
        # arrays of tables, so [[users]] materializes one row per table.
        def plan_walk(toml_string)
          require 'teptris'
          require 'teptris/descriptor'

          stem = plan_stem(toml_string)
          descriptor = plan_descriptors[stem] ||= build_plan_descriptor(stem)
          descriptor.walk(toml_string)
        end

        def plan_stem(toml_string)
          if toml_string =~ /^\[\[users\]\]/
            'users'
          elsif toml_string =~ /^\[\[.*records\]\]|^\[dataset\]/
            'dataset'
          else
            'config'
          end
        end

        def plan_descriptors
          @plan_descriptors ||= {}
        end

        def build_plan_descriptor(stem)
          require 'teptris'
          require 'teptris/descriptor'

          case stem
          when 'users'
            ::Teptris::Descriptor.build(
              children: [
                { name: 'users', kind: :nested, plan: {
                  children: [
                    { name: 'id', kind: :scalar }, { name: 'name', kind: :scalar },
                    { name: 'email', kind: :scalar }, { name: 'created_at', kind: :scalar }
                  ]
                } }
              ]
            )
          when 'dataset'
            ::Teptris::Descriptor.build(
              children: [
                { name: 'dataset', kind: :nested, plan: {
                  children: [
                    { name: 'header', kind: :nested, plan: {
                      children: [
                        { name: 'created', kind: :scalar }, { name: 'count', kind: :scalar },
                        { name: 'format', kind: :scalar }
                      ]
                    } },
                    { name: 'records', kind: :nested, plan: {
                      children: [
                        { name: 'id', kind: :scalar }, { name: 'timestamp', kind: :scalar }
                      ]
                    } }
                  ]
                } }
              ]
            )
          else
            ::Teptris::Descriptor.build(
              children: [
                { name: 'config', kind: :nested, plan: {
                  children: [
                    { name: 'database', kind: :nested, plan: {
                      children: %w[host port name user password].map do |f|
                        { name: f, kind: :scalar }
                      end
                    } },
                    { name: 'cache', kind: :nested, plan: {
                      children: [{ name: 'enabled', kind: :scalar }, { name: 'ttl', kind: :scalar }]
                    } }
                  ]
                } }
              ]
            )
          end
        end

        def library_require_name
          'teptris'
        end
      end
    end
  end
end
