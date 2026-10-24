# frozen_string_literal: true

module Prosemirror
  module Nodes
    class BulletList < NodeType
      group :block, :list
      content "list_item+"
      parse_html tag: "ul"

      def view_template(&) = ul(&)

      # `-` items, or `*` right after another bullet list, which would otherwise continue it.
      def to_markdown(markdown, parent, index)
        marker = markdown.list_after_list?(parent, index) ? "* " : "- "
        markdown.render_list(node, "  ") { marker }
      end
    end
  end
end
