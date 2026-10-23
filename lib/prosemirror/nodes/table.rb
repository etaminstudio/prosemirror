# frozen_string_literal: true

module Prosemirror
  module Nodes
    class Table < NodeType
      group :block
      content "table_row+"
      parse_html tag: "table"

      def view_template(&)
        table { tbody(&) }
      end
    end
  end
end
