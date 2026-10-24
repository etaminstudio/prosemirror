# frozen_string_literal: true

module Prosemirror
  module Nodes
    # Tiptap's mention: `@label`, or `@id` without a label. `mentionSuggestionChar` is the character typed
    # to insert it, `@` by default, which tells mentions of different kinds apart.
    class Mention < NodeType
      group :inline
      inline

      prop :id, _Union?(String, Integer), parse_html: ->(element) { element["data-id"] }
      prop :label, _String?, parse_html: ->(element) { element["data-label"] }
      prop :mention_suggestion_char, _String(length: 1..), default: "@", json: "mentionSuggestionChar",
        parse_html: ->(element) { element["data-mention-suggestion-char"] }
      leaf_text { |node| display_text(node.attrs) }
      parse_html tag: %(span[data-type="mention"])

      def view_template
        span(data: {type: "mention", id: @id, label: @label, mention_suggestion_char: @mention_suggestion_char}) do
          self.class.display_text(node.attrs)
        end
      end

      # Its text, or with `html: true`, its HTML, which Markdown import reads back.
      def to_markdown(markdown, _parent, _index)
        if markdown.html?
          markdown.write(markdown.node_html(node))
        else
          markdown.text(self.class.display_text(node.attrs))
        end
      end

      def self.display_text(attrs) = "#{attrs[:mention_suggestion_char] || "@"}#{attrs[:label] || attrs[:id]}"
    end
  end
end
