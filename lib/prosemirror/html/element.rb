# frozen_string_literal: true

module Prosemirror
  module HTML
    # An element, with a lowercase name, attributes with lowercase names and decoded values, and
    # children. The import works on these rather than on the parser's own tree.
    class Element
      attr_reader :name, :attributes, :children
      attr_accessor :parent

      def initialize(name, attributes = {})
        @name = name
        @attributes = attributes
        @children = []
      end

      def append(child)
        child.parent = self
        @children << child
        child
      end

      def element?
        true
      end

      def [](attribute)
        @attributes[attribute]
      end

      def key?(attribute)
        @attributes.key?(attribute)
      end

      def classes
        self["class"].to_s.split
      end

      # The declarations of the `style` attribute, with lowercase properties: `{"font-weight" => "bold"}`.
      def style
        @style ||= self["style"].to_s.split(";").each_with_object({}) do |declaration, styles|
          property, value = declaration.split(":", 2)
          next if value.nil? || property.strip.empty?

          styles[property.strip.downcase] = value.strip.sub(/\s*!important\z/i, "")
        end
      end

      def text_content
        @children.map(&:text_content).join
      end

      def element_children
        @children.select(&:element?)
      end

      def first_element_child
        @children.find(&:element?)
      end

      def previous_sibling(child)
        index = @children.index { |candidate| candidate.equal?(child) }
        @children[index - 1] if index&.positive?
      end

      def matches?(selector)
        Selector.parse(selector).match?(self)
      end

      # The first descendant matching the selector, depth first.
      def query(selector)
        compiled = Selector.parse(selector)
        stack = element_children.reverse
        until stack.empty?
          element = stack.pop
          return element if compiled.match?(element)

          stack.concat(element.element_children.reverse)
        end
        nil
      end
    end
  end
end
