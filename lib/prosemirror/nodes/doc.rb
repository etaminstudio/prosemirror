# frozen_string_literal: true

module Prosemirror
  module Nodes
    # The top node of a document. It renders its content only.
    class Doc < NodeType
      content "block+"
    end
  end
end
