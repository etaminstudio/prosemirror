# frozen_string_literal: true

module Prosemirror
  module Marks
    class Strike < MarkType
      parse_html tag: "s"
      parse_html tag: "del"
      parse_html tag: "strike"
      parse_html(style: "text-decoration", consuming: false) { |value| value.include?("line-through") ? {} : false }

      markdown open: "~~", close: "~~", mixable: true, expel_enclosing_whitespace: true

      def view_template(&) = s(&)
    end
  end
end
