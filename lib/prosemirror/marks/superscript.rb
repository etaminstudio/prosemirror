# frozen_string_literal: true

module Prosemirror
  module Marks
    class Superscript < MarkType
      excludes "subscript"
      parse_html tag: "sup"
      parse_html(style: "vertical-align") { |value| (value == "super") ? {} : false }

      def view_template(&) = sup(&)
    end
  end
end
