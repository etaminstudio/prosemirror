# frozen_string_literal: true

module Prosemirror
  module Nodes
    class TableCell < NodeType
      content "block+"

      prop :colspan, _Integer(1..), default: 1, &Coerce::INTEGER
      prop :rowspan, _Integer(1..), default: 1, &Coerce::INTEGER
      prop :colwidth, _Array?(_Integer(1..))

      def view_template(&)
        td(**cell_attributes, &)
      end

      private

      def cell_attributes
        { colspan: (@colspan unless @colspan == 1), rowspan: (@rowspan unless @rowspan == 1) }
      end
    end
  end
end
