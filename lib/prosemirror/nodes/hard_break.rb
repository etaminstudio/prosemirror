# frozen_string_literal: true

module Prosemirror
  module Nodes
    class HardBreak < NodeType
      group :inline
      inline
      leaf_text "\n"
      linebreak_replacement
      parse_html tag: "br"

      def view_template = br

      # A backslash before the newline, unless only line breaks follow.
      def to_markdown(markdown, parent, index)
        markdown.write("\\\n") if parent.content[(index + 1)..].any? { |sibling| sibling.type != node.type }
      end
    end
  end
end
