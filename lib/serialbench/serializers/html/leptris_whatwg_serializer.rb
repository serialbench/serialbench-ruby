# frozen_string_literal: true

require_relative 'leptris_serializer'

module Serialbench
  module Serializers
    module Html
      # The WHATWG-conformant HTML engine (:whatwg mode, 1.9.104+):
      # implied-<head> set and foster parenting — html5lib corpus
      # 294/1555. Priced separately from the :html4 parity engine.
      class LeptrisWhatwgSerializer < LeptrisSerializer
        def name
          'leptris-whatwg'
        end

        def capabilities
          super | Set.new(%i[html5])
        end

        def parse(html_string)
          require 'leptris'
          require 'leptris/xml'
          Leptris::XML.parse_html(html_string, mode: :whatwg)
        end
      end
    end
  end
end
