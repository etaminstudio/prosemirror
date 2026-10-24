# frozen_string_literal: true

module Prosemirror
  module Nodes
    class Paragraph < NodeType
      group :block
      content "inline*"
      parse_html tag: "p"

      def view_template(&) = p(&)

      # Markdown has no empty paragraphs: they are left out.
      def to_markdown(markdown, _parent, _index)
        return if node.content.empty?

        markdown.render_inline(node)
        markdown.close_block(node)
      end
    end
  end
end
