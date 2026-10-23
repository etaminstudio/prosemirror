# frozen_string_literal: true

module Prosemirror
  module Nodes
    module Basic
      # ProseMirror's ordered list. Tiptap's `start` attribute is read as `order`.
      class OrderedList < NodeType
        group :block, :list
        content "list_item+"

        prop :order, Integer, default: 1, aliases: ["start"], &Coerce::INTEGER

        def view_template(&)
          ol(start: (@order unless @order == 1), &)
        end
      end
    end
  end
end
