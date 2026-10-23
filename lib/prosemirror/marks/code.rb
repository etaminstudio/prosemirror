# frozen_string_literal: true

module Prosemirror
  module Marks
    class Code < MarkType
      code

      def view_template(&) = code(&)
    end
  end
end
