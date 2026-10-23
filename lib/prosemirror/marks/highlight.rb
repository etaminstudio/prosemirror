# frozen_string_literal: true

module Prosemirror
  module Marks
    # Tiptap's highlight. `color` must be a hex, named, rgb() or hsl() color, so it is safe in a style.
    class Highlight < MarkType
      COLOR = %r{\A(\#\h{3,8}|[a-z]+|(rgb|hsl)a?\([\d\s.,%/]+\))\z}i

      prop :color, _String?(COLOR)

      def view_template(&)
        mark(data_color: @color, style: @color && "background-color: #{@color}; color: inherit", &)
      end
    end
  end
end
