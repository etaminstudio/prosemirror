# frozen_string_literal: true

module Prosemirror
  module Nodes
    class HardBreak < NodeType
      group :inline
      inline
      leaf_text "\n"

      def view_template = br
    end
  end
end
