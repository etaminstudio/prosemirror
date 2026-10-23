# frozen_string_literal: true

module Prosemirror
  module Marks
    class Superscript < MarkType
      excludes "subscript"

      def view_template(&) = sup(&)
    end
  end
end
