# frozen_string_literal: true

module Prosemirror
  module Marks
    # Tiptap's inline code, which can't be combined with other marks.
    class Code < MarkType
      code
      excludes "_"

      parse_html tag: "code"
      parse_html tag: "tt"

      def view_template(&) = code(&)
    end
  end
end
