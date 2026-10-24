# frozen_string_literal: true

module Prosemirror
  module Nodes
    # Text. Text nodes are rendered by the renderer, not by this type.
    class Text < NodeType
      group :inline

      def to_markdown(markdown, _parent, _index)
        markdown.text(node.text, escape: !markdown.in_autolink)
      end
    end
  end
end
