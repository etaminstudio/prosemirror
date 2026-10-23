# frozen_string_literal: true

module Prosemirror
  # Builds a new document from a block called with each node, children first. See Document#transform.
  #
  # The block returns the node to keep, another node, an array of nodes to put in its place, or nil to
  # remove it. Adjacent text nodes with the same marks are then joined, and empty ones removed. When a
  # node's content changed and no longer has what its content expression requires, the required nodes
  # are added, as an empty paragraph in an empty list item, and reported. Other problems are left for
  # Document#check.
  class Transformer
    def initialize(schema, &block)
      raise ArgumentError, "transform needs a block" unless block

      @schema = schema
      @block = block
    end

    # The root, with its transformed content. The root itself isn't given to the block.
    def call(root)
      path = @schema.json_type_name(root.type)
      filled(root, root.with(content: transform_content(root, path)), path)
    end

    private

    def transform_content(node, path)
      content = node.content.each_with_index.flat_map { |child, index| transform(child, "#{path}.content[#{index}]") }
      Node.join_text(content.reject { |child| child.text? && child.text.empty? })
    end

    # The nodes the block gives for a node, after its content, with their required content added: the block
    # sees an emptied list item, and can remove it.
    def transform(node, path)
      changed = node.content.empty? ? node : node.with(content: transform_content(node, path))
      nodes = case (result = @block.call(changed))
      when nil then []
      when Node then [result]
      when Array then result
      end
      raise ArgumentError, "the transform block returns a node, an array of nodes or nil, not #{result.inspect}" unless nodes&.all?(Node)

      nodes.map { |result_node| filled(node, result_node, path) }
    end

    # The node with its required content added, when its content changed.
    def filled(original, node, path)
      return node if node.content.equal?(original.content) || node.content == original.content

      content = fill(node, node.content, path)
      content.equal?(node.content) ? node : node.with(content: content)
    end

    # The content with the nodes its type requires added in front of it, or after it, when they can be.
    def fill(node, content, path)
      type = @schema.node_type(node.type)
      types = content.map { |child| @schema.node_type(child.type) }
      return content if type.nil? || type.leaf? || types.include?(nil)

      match = @schema.content_match(type)
      return content if match.match_types(types)&.valid_end?

      if (before = match.fill_before(types, @schema, to_end: true))
        added = created(before, node, path) and return added + content
      elsif (after = match.match_types(types)&.fill_before([], @schema, to_end: true))
        added = created(after, node, path) and return content + added
      end
      content
    end

    # Empty nodes of these types, filled with what they require, or nil when one can't be created.
    def created(types, node, path)
      nodes = types.map { |type| @schema.create_and_fill(type) }
      return nil if nodes.include?(nil)

      names = types.map { |type| @schema.json_type_name(type.type_name) }.join(", ")
      @schema.report("added required #{names} to #{@schema.json_type_name(node.type)}", path: path)
      nodes
    end
  end
end
