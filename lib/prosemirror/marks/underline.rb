# frozen_string_literal: true

module Prosemirror
  module Marks
    class Underline < MarkType
      parse_html tag: "u"
      parse_html(style: "text-decoration", consuming: false) { |value| value.include?("underline") ? {} : false }

      def view_template(&) = u(&)
    end
  end
end
