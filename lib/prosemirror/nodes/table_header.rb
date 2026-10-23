# frozen_string_literal: true

module Prosemirror
  module Nodes
    class TableHeader < TableCell
      type_name :table_header

      def view_template(&)
        th(**cell_attributes, &)
      end
    end
  end
end
