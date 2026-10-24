# frozen_string_literal: true

module Prosemirror
  module Marks
    module Basic
      # ProseMirror's inline code, which can be combined with other marks.
      class Code < MarkType
        code

        parse_html tag: "code"

        markdown(**MarkdownSerializer::CODE)

        def view_template(&) = code(&)
      end
    end
  end
end
