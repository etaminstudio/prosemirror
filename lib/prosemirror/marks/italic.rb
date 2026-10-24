# frozen_string_literal: true

module Prosemirror
  module Marks
    class Italic < MarkType
      aliases :em
      parse_html tag: "em"
      parse_html(tag: "i") { |element| element.style["font-style"] != "normal" && {} }
      parse_html style: "font-style=normal", clear_mark: true
      parse_html style: "font-style=italic"

      markdown open: "*", close: "*", mixable: true, expel_enclosing_whitespace: true

      def view_template(&) = em(&)
    end
  end
end
