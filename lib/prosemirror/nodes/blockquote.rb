# frozen_string_literal: true

module Prosemirror
  module Nodes
    class Blockquote < NodeType
      group :block
      content "block+"
      parse_html tag: "blockquote"

      def view_template(&) = blockquote(&)

      def to_markdown(markdown, _parent, _index)
        markdown.wrap_block("> ", nil, node) { markdown.render_content(node) }
      end
    end
  end
end
