# frozen_string_literal: true

module Prosemirror
  module Nodes
    class Table < NodeType
      group :block
      content "table_row+"
      parse_html tag: "table"

      def view_template(&)
        table { tbody(&) }
      end

      # A GitHub Flavored Markdown table: the first row is the header, and gives the columns' alignments. A
      # cell's paragraphs, images and line breaks are joined with `<br>`, and its other blocks, like lists, are
      # written as HTML, which Markdown import reads back with the herb gem.
      def to_markdown(markdown, _parent, _index)
        rows = node.content.map { |row| row.content.map { |cell| cell_markdown(markdown, cell) } }
        columns = rows.map(&:size).max.to_i
        return markdown.close_block(node) if columns.zero?

        aligns = node.content.first.content.map { |cell| cell.attrs[:align] }
        delimiter = Array.new(columns) do |index|
          {"left" => ":--", "center" => ":-:", "right" => "--:"}.fetch(aligns[index].to_s, "---")
        end
        lines = [rows.first, delimiter, *rows.drop(1)].map do |cells|
          "| #{Array.new(columns) { |index| cells[index].to_s }.join(" | ")} |"
        end
        markdown.text(lines.join("\n"), escape: false)
        markdown.close_block(node)
      end

      private

      def cell_markdown(markdown, cell)
        parts = cell.content.map do |block|
          type = markdown.schema.node_type(block.type)
          if type && (type <= Paragraph || type <= Image)
            serializer = MarkdownSerializer.new(markdown.schema, html: markdown.html?)
            serializer.render(block, cell, 0)
            serializer.out.strip.gsub(/\\\n|\n+/, "<br>")
          else
            markdown.node_html(block).gsub("\n", "&#10;")
          end
        end
        # A space after a line break is dropped, as in HTML.
        parts.join("<br>").gsub(/(?:<br>[[:space:]]*)+/, "<br>").delete_prefix("<br>").delete_suffix("<br>").gsub("|", "\\|")
      end
    end
  end
end
