# frozen_string_literal: true

module Prosemirror
  module Nodes
    class Heading < NodeType
      group :block
      content "inline*"

      prop :level, _Integer(1..6), default: 1, &Coerce::INTEGER
      (1..6).each { |level| parse_html tag: "h#{level}", attrs: {level:} }

      def view_template(&) = tag(:"h#{@level}", &)
    end
  end
end
