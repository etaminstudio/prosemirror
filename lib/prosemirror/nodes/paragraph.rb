# frozen_string_literal: true

module Prosemirror
  module Nodes
    class Paragraph < NodeType
      group :block
      content "inline*"
      parse_html tag: "p"

      def view_template(&) = p(&)
    end
  end
end
