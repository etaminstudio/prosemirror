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
      def base_type?
        self == MarkType
      end

      # The marks this mark can't coexist with: mark or group names, `"_"` for all.
      # Defaults to marks of the same type.
      def excludes(spec = nil)
        return @excludes = spec if spec

        inherited_setting(:@excludes, nil)
      end

      def group(*names)
        return @group = names.flat_map { |n| n.to_s.split }.map(&:to_sym) unless names.empty?

        inherited_setting(:@group, [])
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
