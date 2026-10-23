# frozen_string_literal: true

module Prosemirror
  module Nodes
    # Tiptap's code block. `prosemirror-markdown`'s `params` attribute is read as `language`.
    class CodeBlock < NodeType
      group :block
      content "text*"
      marks ""
      code

      # From the `language-*` class of the `<code>` inside `<pre>`.
      prop :language, _String?(/\A[\w#+.-]+\z/), aliases: ["params"], parse_html: lambda { |element|
        element.first_element_child&.classes&.find { |name| name.start_with?("language-") }&.delete_prefix("language-")
      }

      parse_html tag: "pre", preserve_whitespace: :full

      def view_template(&)
        pre { code(class: @language && "language-#{@language}", &) }
      end
    end
  end
end
