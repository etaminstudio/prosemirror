# frozen_string_literal: true

module Prosemirror
  module Nodes
    # Tiptap's ordered list. ProseMirror's `order` attribute is read as `start`.
    class OrderedList < NodeType
      # CSS list styles, used by Google Docs and Word, and their `type`.
      LIST_STYLE_TYPES = {
        "upper-roman" => "I", "lower-roman" => "i", "upper-alpha" => "A", "upper-latin" => "A",
        "lower-alpha" => "a", "lower-latin" => "a"
      }.freeze

      group :block, :list
      content "list_item+"

      prop :start, Integer, default: 1, aliases: ["order"],
        parse_html: ->(element) { element.key?("start") ? element["start"].to_i : 1 }, &Coerce::INTEGER
      prop :type, _Union?("1", "a", "A", "i", "I"), parse_html: ->(element) { OrderedList.type_from_html(element) }

      parse_html tag: "ol"

      # From the `type` attribute, or the list style of the list or of its first item.
      def self.type_from_html(element)
        element["type"] || list_style_type(element) || element.query("li")&.then { |item| list_style_type(item) }
      end

      def self.list_style_type(element)
        LIST_STYLE_TYPES[element.style["list-style-type"].to_s.downcase]
      end

      def view_template(&)
        ol(start: (@start unless @start == 1), type: @type, &)
      end

      def to_markdown(markdown, parent, index)
        self.class.numbered(markdown, node, @start, markdown.list_after_list?(parent, index) ? ")" : ".")
      end

      # Items numbered from `start`, with the numbers aligned. `)` instead of `.` keeps a list right after
      # another ordered list apart from it.
      def self.numbered(markdown, node, start, delimiter = ".")
        width = (start + node.content.size - 1).to_s.length
        markdown.render_list(node, " " * (width + 2)) { |index| "#{(start + index).to_s.rjust(width)}#{delimiter} " }
      end
    end
  end
end
