# frozen_string_literal: true

module Prosemirror
  module Marks
    module Basic
      class Em < MarkType
        aliases :italic
        parse_html tag: "i"
        parse_html tag: "em"
        parse_html style: "font-style=italic"
        parse_html style: "font-style=normal", clear_mark: true

        def view_template(&) = em(&)
      end
    end
  end
end
