# frozen_string_literal: true

module Prosemirror
  module Nodes
    # Tiptap's details: a summary, and content shown when it's open. `open` is the attribute Tiptap keeps with
    # `persist: true`.
    class Details < NodeType
      group :block
      content "details_summary details_content"

      prop :open, _Boolean, default: false, parse_html: ->(element) { element.key?("open") }
      parse_html tag: "details"

      def view_template(&) = details(open: @open, &)

      # As HTML, which GitHub and Markdown import read, with the content in Markdown between blank lines.
      def to_markdown(markdown, _parent, _index)
        summary, content = node.content
        markdown.text("<details#{" open" if @open}>\n#{markdown.node_html(summary)}", escape: false)
        markdown.close_block(node)
        markdown.render(content, node, 1)
        markdown.text("</details>", escape: false)
        markdown.close_block(node)
      end
    end
  end
end
