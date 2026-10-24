# frozen_string_literal: true

module Prosemirror
  module Nodes
    # Tiptap's image, a block node. Without an allowed `src`, it renders nothing.
    class Image < NodeType
      group :block

      prop :src, _String(length: 1..), url: true
      prop :alt, _String?
      prop :title, _String?
      prop :width, _Integer?(1..), &Coerce::INTEGER
      prop :height, _Integer?(1..), &Coerce::INTEGER
      parse_html tag: %(img[src]:not([src^="data:"]))

      def view_template
        src = safe_url(@src)
        img(src: src, alt: @alt, title: @title, width: @width, height: @height) if src
      end

      # `![alt](src "title")`, or HTML with `html: true` when it has dimensions. Images in a row share a line,
      # as Markdown would give them back: in separate paragraphs, each would come back after an empty one.
      def to_markdown(markdown, parent, index)
        markdown.write(" ") if index.positive? && parent.content[index - 1].type == node.type
        if markdown.html? && (@width || @height)
          markdown.write(markdown.node_html(node))
        else
          markdown.write(self.class.markdown_image(markdown, @src, @alt, @title))
        end
        markdown.close_block(node) unless parent.content[index + 1]&.type == node.type
      end

      def self.markdown_image(markdown, src, alt, title)
        "![#{markdown.esc(alt.to_s)}](#{markdown.url(src)}#{markdown.title(title)})"
      end
    end
  end
end
