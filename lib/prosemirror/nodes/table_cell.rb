# frozen_string_literal: true

module Prosemirror
  module Nodes
    class TableCell < NodeType
      ALIGNMENTS = %w[left right center].freeze

      content "block+"

      prop :colspan, _Integer(1..), default: 1, &Coerce::INTEGER
      prop :rowspan, _Integer(1..), default: 1, &Coerce::INTEGER
      prop :colwidth, _Array?(_Integer(1..)),
        parse_html: ->(element) { element["colwidth"]&.split(",")&.map(&:to_i) }
      # From the `text-align` style, or the old `align` attribute.
      prop :align, _Union?(*ALIGNMENTS), parse_html: lambda { |element|
        (element.style["text-align"] || element["align"]).to_s.strip.downcase.then { |value| value if ALIGNMENTS.include?(value) }
      }

      parse_html tag: "td"

      def view_template(&)
        td(**cell_attributes, &)
      end

      private

      def cell_attributes
        {colspan: (@colspan unless @colspan == 1), rowspan: (@rowspan unless @rowspan == 1),
         style: @align && "text-align: #{@align}"}
      end
    end
  end
end
