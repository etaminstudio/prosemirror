# frozen_string_literal: true

module Prosemirror
  module Nodes
    # Tiptap's task list. Also imported from GitHub's HTML, as commonmarker renders it, when every item has a
    # checkbox.
    class TaskList < NodeType
      group :block, :list
      content "task_item+"
      parse_html tag: %(ul[data-type="taskList"]), priority: 51
      parse_html(tag: "ul.contains-task-list", priority: 51) do |element|
        element.element_children.all? { |item| item.matches?("li.task-list-item") } && {}
      end

      def view_template(&) = ul(data_type: "taskList", &)

      # `- [x]` items. Its markers alternate with bullet lists', or Markdown would join them.
      def to_markdown(markdown, parent, index)
        marker = BulletList.marker(markdown, parent, index)
        markdown.render_list(node, "  ") { marker }
      end
    end
  end
end
