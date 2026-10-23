# frozen_string_literal: true

module Prosemirror
  module Nodes
    class Blockquote < NodeType
      group :block
      content "block+"

      def view_template(&) = blockquote(&)
    end
  end
end
