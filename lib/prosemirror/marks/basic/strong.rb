# frozen_string_literal: true

module Prosemirror
  module Marks
    module Basic
      class Strong < MarkType
        aliases :bold
        parse_html tag: "strong"
        parse_html(tag: "b") { |element| element.style["font-weight"] != "normal" && {} }
        parse_html style: "font-weight=400", clear_mark: true
        parse_html(style: "font-weight") { |value| value.match?(Bold::BOLD) && {} }

        def view_template(&) = strong(&)
      end
    end
  end
end
