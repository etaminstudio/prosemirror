# frozen_string_literal: true

module Prosemirror
  module Marks
    module Basic
      class Strong < MarkType
        aliases :bold

        def view_template(&) = strong(&)
      end
    end
  end
end
