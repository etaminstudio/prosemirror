# frozen_string_literal: true

module Prosemirror
  module Marks
    class Bold < MarkType
      # The `font-weight` values that mean bold.
      BOLD = /\A(bold(er)?|[5-9]\d{2,})\z/

      aliases :strong

      parse_html tag: "strong"
      parse_html(tag: "b") { |element| element.style["font-weight"] != "normal" && {} }
      parse_html style: "font-weight=400", clear_mark: true
      parse_html(style: "font-weight") { |value| value.match?(BOLD) && {} }

      def view_template(&) = strong(&)
    end
  end
end
