# frozen_string_literal: true

module Prosemirror
  module Marks
    class Subscript < MarkType
      excludes "superscript"

      def view_template(&) = sub(&)
    end
  end
end
