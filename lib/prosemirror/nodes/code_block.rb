# frozen_string_literal: true

module Prosemirror
  module Nodes
    # Tiptap's code block. `prosemirror-markdown`'s `params` attribute is read as `language`.
    class CodeBlock < NodeType
      group :block
      content "text*"
      marks ""
      code

      prop :language, _String?(/\A[\w#+.-]+\z/), aliases: ["params"]

      def view_template(&)
        pre { code(class: @language && "language-#{@language}", &) }
      end
    end
  end
end
