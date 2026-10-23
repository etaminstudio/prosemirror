# frozen_string_literal: true

module Prosemirror
  module Marks
    class Bold < MarkType
      aliases :strong

      def view_template(&) = strong(&)
    end
  end
end
