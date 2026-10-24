# frozen_string_literal: true

module Prosemirror
  module Nodes
    # Tiptap's task item, with its content in a `div` after the checkbox. Its content is Tiptap's with
    # `nested: true`, which also accepts documents written without it.
    class TaskItem < NodeType
      content "paragraph block*"

      # From Tiptap's `data-checked`, or the checkbox.
      prop :checked, _Boolean, default: false, parse_html: lambda { |element|
        if element.key?("data-checked")
          ["", "true"].include?(element["data-checked"])
        else
          element.query(%(input[type="checkbox"]))&.key?("checked") || false
        end
      }

      parse_html tag: %(li[data-type="taskItem"]), priority: 51, content_element: "div"
      parse_html tag: "li.task-list-item", priority: 51, context: "task_list/"

      def view_template(&)
        li(data_checked: @checked.to_s, data_type: "taskItem") do
          label do
            input(type: "checkbox", checked: @checked)
            span
          end
          div(&)
        end
      end

      # `[x] ` before its content, without the space when its first paragraph is empty.
      def to_markdown(markdown, _parent, _index)
        markdown.write(@checked ? "[x]" : "[ ]")
        markdown.write(" ") unless node.content.first&.content.to_a.empty?
        markdown.render_content(node)
      end
    end
  end
end
