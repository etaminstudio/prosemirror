# frozen_string_literal: true

module Prosemirror
  module HTML
    # A text node, with its character references decoded.
    class Text
      attr_reader :value
      attr_accessor :parent

      def initialize(value)
        @value = value
      end

      def text_content
        @value
      end

      def element?
        false
      end
    end
  end
end
