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

      def to_markdown(markdown, _parent, _index)
        self.class.fenced(markdown, node, @language)
      end

      # A fenced code block, with a fence longer than any run of backticks in the code.
      # @api private
      def self.fenced(markdown, node, language)
        code = node.text_content
        fence = "`" * [3, (code.scan(/`{3,}/).map(&:length).max || 0) + 1].max
        markdown.write("#{fence}#{language}\n")
        markdown.text(code, escape: false)
        markdown.ensure_new_line
        markdown.write(fence)
        markdown.close_block(node)
      end
    end
  end
end
