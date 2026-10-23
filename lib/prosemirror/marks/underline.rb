# frozen_string_literal: true

module Prosemirror
  module Marks
    class Underline < MarkType
      def view_template(&) = u(&)
    end
  end
end
