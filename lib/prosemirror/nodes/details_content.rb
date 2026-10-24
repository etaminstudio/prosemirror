# frozen_string_literal: true

module Prosemirror
  module Nodes
    class DetailsContent < NodeType
      content "block+"
      parse_html tag: %(div[data-type="detailsContent"])

      def view_template(&) = div(data_type: "detailsContent", &)
    end
  end
end
