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
    # @api private
    BLANK = /\A[[:space:]]*\z/

    # @api private
    EMPTY_HASH = {}.freeze
    # @api private
    EMPTY_ARRAY = [].freeze

    prop :type, Symbol
    prop :attrs, _Hash(Symbol, _Any?), default: EMPTY_HASH
    prop :unknown_attrs, _Hash(String, _Any?), default: EMPTY_HASH
    prop :content, _Array(Node), default: EMPTY_ARRAY
    prop :marks, _Array(Mark), default: EMPTY_ARRAY
    prop :text, _String?

    # The type as a Symbol, and frozen values. Done here rather than with Literal coercion blocks, which
    # cost an `instance_exec` each, for each of the many nodes a document has.
    def initialize(type:, attrs: EMPTY_HASH, unknown_attrs: EMPTY_HASH, content: EMPTY_ARRAY, marks: EMPTY_ARRAY, text: nil)
      super(type: type.is_a?(String) ? type.to_sym : type, attrs: Coerce.frozen(attrs), unknown_attrs: Coerce.frozen(unknown_attrs),
            content: Coerce.frozen(content), marks: Coerce.frozen(marks), text: Coerce.frozen(text))
    end

    # The nodes with adjacent text nodes that have the same marks joined, as in ProseMirror.
    # @api private
    def self.join_text(nodes)
      return nodes unless joinable_text?(nodes)

      nodes.each_with_object([]) do |node, joined|
        previous = joined.last
        if previous&.text? && node.text? && previous.marks == node.marks
          joined[-1] = previous.with(text: previous.text + node.text)
        else
          joined << node
        end
      end
    end

    # Whether two adjacent text nodes have the same marks. A loop: this runs for each node with content.
    def self.joinable_text?(nodes)
      index = 1
      while index < nodes.size
        previous = nodes[index - 1]
        node = nodes[index]
        return true if previous.text? && node.text? && previous.marks == node.marks

        index += 1
      end
      false
    end
    private_class_method :joinable_text?

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
