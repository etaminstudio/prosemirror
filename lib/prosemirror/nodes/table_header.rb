# frozen_string_literal: true

module Prosemirror
  module Nodes
    class TableHeader < TableCell
      type_name :table_header

      parse_html tag: "th"

      def view_template(&)
        th(**cell_attributes, &)
      end
    end
  end
end
