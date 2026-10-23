# frozen_string_literal: true

module Prosemirror
  module Nodes
    class ListItem < NodeType
      content "paragraph block*"

      def view_template(&) = li(&)
    end
  end
end
