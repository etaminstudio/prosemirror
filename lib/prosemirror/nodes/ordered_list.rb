# frozen_string_literal: true

module Prosemirror
  module Nodes
    # Tiptap's ordered list. ProseMirror's `order` attribute is read as `start`.
    class OrderedList < NodeType
      group :block, :list
      content "list_item+"

      prop :start, Integer, default: 1, aliases: ["order"], &Coerce::INTEGER
      prop :type, _Union?("1", "a", "A", "i", "I")

      def view_template(&)
        ol(start: (@start unless @start == 1), type: @type, &)
      end
    end
  end
end
