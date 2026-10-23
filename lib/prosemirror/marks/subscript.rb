# frozen_string_literal: true

module Prosemirror
  module Marks
    class Subscript < MarkType
      excludes "superscript"
      parse_html tag: "sub"
      parse_html(style: "vertical-align") { |value| (value == "sub") ? {} : false }

      def view_template(&) = sub(&)
    end
  end
end
