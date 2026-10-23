# frozen_string_literal: true

module Prosemirror
  module Nodes
    module Basic
      # ProseMirror's code block, without attributes.
      class CodeBlock < NodeType
        group :block
        content "text*"
        marks ""
        code

        def view_template(&)
          pre { code(&) }
        end
      end
    end
  end
end
