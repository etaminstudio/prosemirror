# frozen_string_literal: true

module Prosemirror
  module Marks
    class Strike < MarkType
      def view_template(&) = s(&)
    end
  end
end
