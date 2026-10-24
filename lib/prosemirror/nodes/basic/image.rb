# frozen_string_literal: true

module Prosemirror
  module Nodes
    module Basic
      # ProseMirror's image, an inline node. Without an allowed `src`, it renders nothing.
      class Image < NodeType
        group :inline
        inline

        prop :src, _String(length: 1..)
        prop :alt, _String?
        prop :title, _String?
        parse_html tag: "img[src]"

        def view_template
          src = safe_url(@src)
          img(src: src, alt: @alt, title: @title) if src
        end

        def to_markdown(markdown, _parent, _index)
          markdown.write(Nodes::Image.markdown_image(markdown, @src, @alt, @title))
        end
      end
    end
  end
end
