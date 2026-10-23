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
    end
  end
end
