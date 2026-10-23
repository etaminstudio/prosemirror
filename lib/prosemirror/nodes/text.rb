# frozen_string_literal: true

module Prosemirror
  module Nodes
    # Text. Text nodes are rendered by the renderer, not by this type.
    class Text < NodeType
      group :inline
    end
  end
end
