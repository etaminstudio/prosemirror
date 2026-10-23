# frozen_string_literal: true

module Prosemirror
  module Nodes
    class HorizontalRule < NodeType
      group :block
      parse_html tag: "hr"

      def view_template = hr
    end
  end
end
