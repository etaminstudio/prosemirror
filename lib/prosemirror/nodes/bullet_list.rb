# frozen_string_literal: true

module Prosemirror
  module Nodes
    class BulletList < NodeType
      group :block, :list
      content "list_item+"
      parse_html tag: "ul"

      def view_template(&) = ul(&)

      # `-` items, or `*` right after another bullet or task list, which would otherwise continue it.
      def to_markdown(markdown, parent, index)
        marker = self.class.marker(markdown, parent, index)
        markdown.render_list(node, "  ") { marker }
      end

      # Bullet and task lists share markers.
      def self.marker(markdown, parent, index)
        after_list = markdown.list_after_list?(parent, index) do |sibling|
          type = markdown.schema.node_type(sibling.type)
          !type.nil? && (type <= BulletList || type <= TaskList)
        end
        after_list ? "* " : "- "
      end
    end
  end
end
