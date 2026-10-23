# frozen_string_literal: true

module Prosemirror
  module Marks
    module Basic
      class Em < MarkType
        aliases :italic

        def view_template(&) = em(&)
      end
    end
  end
end
