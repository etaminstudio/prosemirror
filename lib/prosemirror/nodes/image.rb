# frozen_string_literal: true

module Prosemirror
  module Nodes
    # Tiptap's image, a block node. Without an allowed `src`, it renders nothing.
    class Image < NodeType
      group :block

      prop :src, _String(length: 1..)
      prop :alt, _String?
      prop :title, _String?
      prop :width, _Integer?(1..), &Coerce::INTEGER
      prop :height, _Integer?(1..), &Coerce::INTEGER

      def view_template
        src = safe_url(@src)
        img(src: src, alt: @alt, title: @title, width: @width, height: @height) if src
      end
    end
  end
end
