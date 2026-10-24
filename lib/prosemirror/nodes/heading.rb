# frozen_string_literal: true

module Prosemirror
  module Nodes
    class Heading < NodeType
      group :block
      content "inline*"

      prop :level, _Integer(1..6), default: 1, &Coerce::INTEGER
      (1..6).each { |level| parse_html tag: "h#{level}", attrs: {level:} }

      def view_template(&) = tag(:"h#{@level}", &)

      def to_markdown(markdown, _parent, _index)
        markdown.write("#{"#" * @level} ")
        markdown.render_inline(node, from_block_start: false)
        markdown.close_block(node)
      end
    end
  end
end
