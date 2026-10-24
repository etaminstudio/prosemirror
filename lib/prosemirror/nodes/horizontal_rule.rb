# frozen_string_literal: true

module Prosemirror
  module Nodes
    class HorizontalRule < NodeType
      group :block
      parse_html tag: "hr"

      def view_template = hr

      def to_markdown(markdown, _parent, _index)
        markdown.write("---")
        markdown.close_block(node)
      end
    end
  end
end
