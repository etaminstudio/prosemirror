# frozen_string_literal: true

module Prosemirror
  # Renders nodes and their marks. Included in the HTML renderer, and in node and mark types
  # so that they can render any part of their content.
  module Rendering
    # Render a list of nodes with their marks. A mark shared by adjacent nodes is rendered once.
    def render_content(nodes)
      render_fragment(nodes, 0)
    end

    # The schema of the document being rendered.
    def prosemirror_schema
      @_prosemirror_schema
    end

    # The URL, when its scheme is allowed, after the schema's `resolve_url` or `resolve_urls`. Otherwise nil.
    def safe_url(url)
      prosemirror_schema.safe_url(url, @_prosemirror_urls)
    end

    private

    def render_fragment(nodes, depth)
      index = 0
      while index < nodes.size
        mark = nodes[index].marks[depth]
        unless mark
          render_node(nodes[index])
          index += 1
          next
        end

        last = last_index_with_mark(nodes, index, depth, mark)
        render_marked(mark, nodes[index..last], depth)
        index = last + 1
      end
    end

    def last_index_with_mark(nodes, index, depth, mark)
      return index unless prosemirror_schema.mark_type(mark.type)&.spanning?

      index += 1 while index + 1 < nodes.size && nodes[index + 1].marks[depth] == mark
      index
    end

    def render_marked(mark, nodes, depth)
      mark_type = prosemirror_schema.mark_type(mark.type)
      return render_fragment(nodes, depth + 1) unless mark_type

      render(prepare(mark_type.new(**mark.attrs))) { render_fragment(nodes, depth + 1) }
    end

    def render_node(node)
      return plain(node.text) if node.text?

      node_type = prosemirror_schema.node_type(node.type)
      return render_content(node.content) unless node_type

      component = prepare(node_type.new(**node.attrs))
      component.instance_variable_set(:@_prosemirror_node, node)
      render(component) { render_content(node.content) }
    end

    def prepare(component)
      component.instance_variable_set(:@_prosemirror_schema, prosemirror_schema)
      component.instance_variable_set(:@_prosemirror_urls, @_prosemirror_urls)
      component
    end
  end
end
