# frozen_string_literal: true

module Prosemirror
  module Marks
    class Italic < MarkType
      aliases :em

      def view_template(&) = em(&)
    end
  end
end
