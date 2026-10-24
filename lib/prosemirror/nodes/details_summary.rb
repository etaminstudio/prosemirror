# frozen_string_literal: true

module Prosemirror
  module Nodes
    class DetailsSummary < NodeType
      content "text*"
      parse_html tag: "summary"

      def view_template(&) = summary(&)
    end
  end
end
