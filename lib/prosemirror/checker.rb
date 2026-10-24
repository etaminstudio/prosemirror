# frozen_string_literal: true

module Prosemirror
  # Checks a document against its schema, as ProseMirror's `Node#check`, and raises InvalidDocument for the
  # first problem, with its path. See Document#check.
  #
  # Rendering and JSON parsing don't need valid content: they render what they get. This checks what
  # they don't: node and mark types, attributes, content expressions, and the marks each node allows.
  class Checker
    def initialize(schema)
      @schema = schema
    end

    def call(root)
      name = @schema.json_type_name(root.type)
      invalid("the top node is #{name}, not #{@schema.top_node}", name) unless root.type == @schema.top_node
      check(root, name)
    end

    private

    def check(node, path)
      type = @schema.node_type(node.type) or invalid("unknown node type #{@schema.json_type_name(node.type)}", path)
      return check_text(node, path) if node.text?

      check_attrs(type, node.attrs, path)
      node.content.each_with_index do |child, index|
        @schema.node_type(child.type) or invalid("unknown node type #{@schema.json_type_name(child.type)}", "#{path}.content[#{index}]")
      end
      check_content(type, node, path)
      node.content.each_with_index do |child, index|
        child_path = "#{path}.content[#{index}]"
        check_marks(type, child, child_path)
        check(child, child_path)
      end
    end

    def check_text(node, path)
      invalid("empty text node", path) if node.text.to_s.empty?
      invalid("text nodes have no content", path) unless node.content.empty?
    end

    def check_content(type, node, path)
      if type.leaf?
        invalid("#{name(type)} has no content, but has #{node.content.size} nodes", path) unless node.content.empty?
        return
      end

      types = node.content.map { |child| @schema.node_type(child.type) }
      return if @schema.content_match(type).match_types(types)&.valid_end?

      found = node.content.map { |child| @schema.json_type_name(child.type) }.join(" ")
      invalid("invalid content for #{name(type)}: #{found.empty? ? "nothing" : found}", path)
    end

    def check_marks(parent, node, path)
      node.marks.each_with_index do |mark, index|
        mark_type = @schema.mark_type(mark.type) or invalid("unknown mark type #{@schema.json_type_name(mark.type)}", "#{path}.marks[#{index}]")
        check_attrs(mark_type, mark.attrs, "#{path}.marks[#{index}]")
        invalid("#{name(parent)} doesn't allow #{name(mark_type)} marks", path) unless parent.allows_mark?(mark_type, @schema)
      end
      sorted = node.marks.reduce([]) { |set, mark| @schema.add_mark(mark, set) }
      invalid("invalid marks: #{node.marks.map { |mark| @schema.json_type_name(mark.type) }.join(" ")}", path) unless sorted == node.marks
    end

    # Attributes are valid when building them from their JSON reports nothing and changes nothing.
    def check_attrs(type, attrs, path)
      problems = []
      built = type.build_attrs(type.serialize_attrs(attrs), report: ->(message) { problems << message })
      invalid(problems.first, path) unless problems.empty?
      invalid("invalid attributes: #{attrs.inspect}", path) unless built == attrs
    end

    def name(type)
      @schema.json_type_name(type.type_name)
    end

    def invalid(message, path)
      raise InvalidDocument.new(message, path: path)
    end
  end
end
