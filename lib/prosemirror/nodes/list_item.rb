# frozen_string_literal: true

module Prosemirror
  module Nodes
    class ListItem < NodeType
      content "paragraph block*"
      parse_html tag: "li"

      def view_template(&) = li(&)

      def to_markdown(markdown, _parent, _index)
        markdown.render_content(node)
      end
    end
  end
end
