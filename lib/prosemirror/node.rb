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
    # Whitespace, including non-breaking spaces.
    BLANK = /\A[[:space:]]*\z/

    prop :type, Symbol, &Coerce::SYMBOL
    prop :attrs, _Hash(Symbol, _Any?), default: {}.freeze, &Coerce::FROZEN
    prop :unknown_attrs, _Hash(String, _Any?), default: {}.freeze, &Coerce::FROZEN
    prop :content, _Array(Node), default: [].freeze, &Coerce::FROZEN
    prop :marks, _Array(Mark), default: [].freeze, &Coerce::FROZEN
    prop :text, _String?, &Coerce::FROZEN

    # The nodes with adjacent text nodes that have the same marks joined, as in ProseMirror.
    def self.join_text(nodes)
      nodes.each_with_object([]) do |node, joined|
        previous = joined.last
        if previous&.text? && node.text? && previous.marks == node.marks
          joined[-1] = previous.with(text: previous.text + node.text)
        else
          joined << node
        end
      end
    end

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

    # Whether the node shows nothing: no text but whitespace, and no leaf nodes but line breaks, like an
    # empty paragraph, or a list item holding one. The schema says which nodes are leaves: an image isn't
    # blank, and neither is a node of a type it doesn't know.
    def blank?(schema = Prosemirror.schema)
      [self, *descendants].none? do |node|
        next !BLANK.match?(node.text) if node.text?

        type = schema.node_type(node.type)
        type.nil? || (type.leaf? && !type.linebreak_replacement?)
      end
    end

    def same_markup?(other)
      @type == other.type && @attrs == other.attrs && @unknown_attrs == other.unknown_attrs && @marks == other.marks
    end
  end
end
