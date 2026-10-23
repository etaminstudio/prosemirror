# frozen_string_literal: true

module Prosemirror
  # The base class of node types. A node type is a Phlex component: `view_template` renders a node,
  # and yields to render its content. Attributes are Literal properties, available as instance variables.
  #
  #   class Heading < Prosemirror::NodeType
  #     group :block
  #     content "inline*"
  #     prop :level, _Integer(1..6), default: 1
  #
  #     def view_template(&) = tag(:"h#{@level}", &)
  #   end
  #
  # The options follow ProseMirror's NodeSpec: https://prosemirror.net/docs/ref/#model.NodeSpec
  class NodeType < Phlex::HTML
    extend Literal::Properties
    extend TypeDefinition
    include Rendering

    class << self
      def base_type?
        self == NodeType
      end

      # The content expression, such as `"block+"`. Nodes without one are leaves.
      def content(expression = nil)
        return @content = ContentExpression.new(expression) if expression

        inherited_setting(:@content, nil)
      end

      # The groups this type belongs to, such as `:block` or `:inline`.
      def group(*names)
        return @group = names.flat_map { |n| n.to_s.split }.map(&:to_sym) unless names.empty?

        inherited_setting(:@group, [])
      end

      def inline(value = true)
        @inline = value
      end

      def inline?
        inherited_setting(:@inline, false) || group.include?(:inline)
      end

      def block?
        !inline?
      end

      def leaf?
        content.nil?
      end

      # The marks allowed inside this node: mark or group names, `"_"` for all, `""` for none.
      def marks(spec = nil)
        return @marks = spec if spec

        inherited_setting(:@marks, nil)
      end

      # `:pre` to keep whitespace when parsing. Implied by `code`.
      def whitespace(value = nil)
        return @whitespace = value if value

        inherited_setting(:@whitespace, code? ? :pre : :normal)
      end

      def code(value = true)
        @code = value
      end

      def code?
        inherited_setting(:@code, false)
      end

      # The text of a leaf node in `to_text`, as a String or a block called with the node.
      def leaf_text(text = nil, &block)
        return @leaf_text = text || block if text || block

        inherited_setting(:@leaf_text, nil)
      end

      def text_for(node)
        value = leaf_text
        value.respond_to?(:call) ? value.call(node).to_s : value.to_s
      end

      # This inline node stands for a newline, as ProseMirror's `linebreakReplacement`: when importing
      # HTML whose whitespace is preserved, newlines become nodes of this type.
      def linebreak_replacement(value = true)
        @linebreak_replacement = value
      end

      def linebreak_replacement?
        inherited_setting(:@linebreak_replacement, false)
      end

      # Whether marks of this type can be applied inside this node, according to its `marks` option.
      def allows_mark?(mark_type, schema)
        case marks
        when nil then schema.content_match(self).inline_content?
        when "_" then true
        when "" then false
        else
          names = marks.split.map(&:to_sym)
          names.include?(mark_type.type_name) || names.intersect?(mark_type.group)
        end
      end
    end

    # The node being rendered.
    def node
      @_prosemirror_node
    end

    # Render the node's content when no `view_template` is defined.
    def view_template
      yield if block_given?
    end
  end
end
