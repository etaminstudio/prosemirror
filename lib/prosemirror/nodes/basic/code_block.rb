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
        parse_html tag: "pre", preserve_whitespace: :full

        def view_template(&)
          pre { code(&) }
        end
      end
    end
  end
end
