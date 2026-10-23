# frozen_string_literal: true

module Prosemirror
  module Nodes
    class Paragraph < NodeType
      group :block
      content "inline*"

      def view_template(&) = p(&)
    end
  end
end
