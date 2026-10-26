# frozen_string_literal: true

module Prosemirror
  # The base class of mark types. A mark type is a Phlex component: `view_template` renders one element
  # and yields to render the marked content. Attributes are Literal properties.
  #
  #   class Bold < Prosemirror::MarkType
  #     def view_template(&) = strong(&)
  #   end
  #
  # The options follow ProseMirror's MarkSpec: https://prosemirror.net/docs/ref/#model.MarkSpec
  class MarkType < Phlex::HTML
    extend Literal::Properties
    extend TypeDefinition
    include Rendering

    class << self
      # @api private
      def base_type?
        self == MarkType
      end

      # The marks this mark can't coexist with: mark or group names, `"_"` for all.
      # Defaults to marks of the same type.
      def excludes(spec = nil)
        return @excludes = spec if spec

        inherited_setting(:@excludes, nil)
      end

      # Whether this mark can't coexist with marks of the other type.
      def excludes?(other)
        case excludes
        when nil then other.type_name == type_name
        when "_" then true
        else
          names = excludes.split.map(&:to_sym)
          names.include?(other.type_name) || names.intersect?(other.group)
        end
      end

      def group(*names)
        return @group = names.flat_map { |n| n.to_s.split }.map(&:to_sym) unless names.empty?

        inherited_setting(:@group, [])
      end

      # The mark's place in its schema, as Tiptap's `priority`: marks with a higher priority come first, and
      # marks with the same priority keep the schema's order. Defaults to 100.
      def priority(value = nil)
        return @priority = value if value

        inherited_setting(:@priority, 100)
      end

      # The mark's Markdown syntax, as prosemirror-markdown's MarkSerializerSpec:
      # - `open` and `close`: strings, or blocks called with the MarkdownSerializer, the mark, the parent node
      #   and the index of the marked node;
      # - `mixable`: the mark can open and close in any order with other mixable marks, like `*` and `**`;
      # - `expel_enclosing_whitespace`: spaces at the edges move outside the mark, as emphasis requires;
      # - `escape: false`: the content isn't escaped, as in inline code. The mark must come last.
      # Without it, the mark keeps only its text, or its HTML with `to_markdown(html: true)`.
      def markdown(open:, close:, mixable: false, expel_enclosing_whitespace: false, escape: true)
        @markdown_spec = {open:, close:, mixable:, expel_enclosing_whitespace:, escape:}.freeze
      end

      # @api private
      def markdown_spec
        inherited_setting(:@markdown_spec, nil)
      end

      # Whether one element can wrap several adjacent nodes with this mark. Defaults to true.
      def spanning(value = nil)
        return @spanning = value unless value.nil?

        inherited_setting(:@spanning, true)
      end

      def spanning?
        spanning
      end

      def code(value = true)
        @code = value
      end

      def code?
        inherited_setting(:@code, false)
      end
    end

    def view_template
      yield if block_given?
    end
  end
end
