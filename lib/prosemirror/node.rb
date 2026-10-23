# frozen_string_literal: true

module Prosemirror
  # A node of a document. Nodes are immutable values, and support pattern matching:
  #
  #   node in { type: :heading, attrs: { level: 1 } }
  #
  # Text nodes have the type `:text` and their content in `text`.
  #
  # `attrs` holds the attributes the node's type declares. `unknown_attrs` holds the others, as written
  # in JSON (for example from a Tiptap extension the schema doesn't know): they are never rendered,
  # and `to_h` gives them back unchanged.
  class Node < Literal::Data
    prop :type, Symbol, &Coerce::SYMBOL
    prop :attrs, _Hash(Symbol, _Any?), default: {}.freeze, &Coerce::FROZEN
    prop :unknown_attrs, _Hash(String, _Any?), default: {}.freeze, &Coerce::FROZEN
    prop :content, _Array(Node), default: [].freeze, &Coerce::FROZEN
    prop :marks, _Array(Mark), default: [].freeze, &Coerce::FROZEN
    prop :text, _String?, &Coerce::FROZEN

    # A copy with some properties changed.
    def with(**changes)
      self.class.new(**to_h, **changes)
    end

    def text?
      @type == :text
    end

    def first_child
      @content.first
    end

    def last_child
      @content.last
    end

    def child_count
      @content.size
    end

    # All text in this node and its descendants, joined without separators.
    def text_content
      return @text if text?

      descendants.select(&:text?).map(&:text).join
    end

    # Iterate over all descendants, depth first, without the node itself.
    def descendants
      return enum_for(:descendants) unless block_given?

      stack = @content.reverse
      until stack.empty?
        node = stack.pop
        yield node
        stack.concat(node.content.reverse)
      end
    end

    def same_markup?(other)
      @type == other.type && @attrs == other.attrs && @unknown_attrs == other.unknown_attrs && @marks == other.marks
    end
  end
end
