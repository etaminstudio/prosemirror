# frozen_string_literal: true

module Prosemirror
  # Extracts the text of a document, as ProseMirror's `textBetween` and Tiptap's `getText` do:
  # textblocks and leaf blocks with text are separated by `block_separator`,
  # and leaf nodes such as hard breaks are replaced by their `leaf_text`.
  # @api private
  class TextSerializer
    def initialize(schema, block_separator: "\n\n")
      @schema = schema
      @block_separator = block_separator
    end

    def call(root)
      text = +""
      first = true

      root.descendants do |node|
        node_type = @schema.node_type(node.type)
        node_text = text_of(node, node_type)

        if separated?(node_type, node_text)
          text << @block_separator unless first
          first = false
        end
        text << node_text
      end

      text
    end

    private

    def text_of(node, node_type)
      return node.text if node.text?
      return "" unless node_type&.leaf?

      node_type.text_for(node)
    end

    def separated?(node_type, node_text)
      return false unless node_type&.block?

      node_type.leaf? ? !node_text.empty? : @schema.textblock?(node_type)
    end
  end
end
