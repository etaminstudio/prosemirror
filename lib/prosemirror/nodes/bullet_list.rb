# frozen_string_literal: true

module Prosemirror
  module Nodes
    class BulletList < NodeType
      group :block, :list
      content "list_item+"

      def view_template(&) = ul(&)
    end
  end
end
