# frozen_string_literal: true

module Prosemirror
  module Nodes
    class TableRow < NodeType
      content "(table_cell | table_header)*"
      parse_html tag: "tr"

      def view_template(&) = tr(&)
    end
  end
end
