# frozen_string_literal: true

module Prosemirror
  # Builds nodes from ProseMirror JSON, and normalizes them as ProseMirror does:
  # marks sorted in schema order, adjacent text with the same marks joined, empty text removed.
  # Invalid parts are fixed and reported to the schema (which raises in strict mode).
  class JSONParser
    MAX_DEPTH = 100

    def initialize(schema)
      @schema = schema
    end

    def parse(json)
      hash = json.is_a?(String) ? JSON.parse(json, max_nesting: (MAX_DEPTH * 2) + 2) : json
      raise ArgumentError, "expected a Hash or a JSON String, got #{json.class}" unless hash.is_a?(Hash)

      root = build_node(hash, "doc", 0) || Node.new(type: @schema.top_node)
      return root if root.type == @schema.top_node

      @schema.report("the top node is #{root.type}, not #{@schema.top_node}", path: "doc")
      Node.new(type: @schema.top_node, content: [root])
    rescue JSON::NestingError
      raise InvalidDocument, "the document is nested more than #{MAX_DEPTH} levels deep"
    end

    private

    def build_node(hash, path, depth)
      return invalid("not a node: #{hash.inspect}", path) unless hash.is_a?(Hash)
      return invalid("nested more than #{MAX_DEPTH} levels deep", path) if depth > MAX_DEPTH

      name = fetch(hash, "type")
      return invalid("missing node type", path) unless name.is_a?(String) || name.is_a?(Symbol)
      return build_text(hash, path) if name.to_s == "text"

      node_type = @schema.node_type(name)
      return build_unknown(hash, name, path, depth) unless node_type

      given = fetch(hash, "attrs")
      attrs = node_type.build_attrs(given, report: reporter(path))
      return invalid("removed #{name} node", path) unless attrs

      Node.new(type: node_type.type_name, attrs: attrs, unknown_attrs: node_type.unknown_attrs(given),
        content: build_content(hash, path, depth), marks: build_marks(fetch(hash, "marks"), path))
    end

    def build_text(hash, path)
      text = fetch(hash, "text")
      return invalid("text node without text", path) unless text.is_a?(String)
      return nil if text.empty?

      Node.new(type: :text, text: text, marks: build_marks(fetch(hash, "marks"), path))
    end

    def build_unknown(hash, name, path, depth)
      invalid("unknown node type #{name}", path)
      attrs = fetch(hash, "attrs")
      Node.new(type: Naming.snake(name), attrs: attrs.is_a?(Hash) ? attrs.transform_keys(&:to_sym) : {},
        content: build_content(hash, path, depth), marks: build_marks(fetch(hash, "marks"), path))
    end

    def build_content(hash, path, depth)
      content = fetch(hash, "content")
      return [] if content.nil?
      return invalid("content is not a list", path) || [] unless content.is_a?(Array)

      nodes = content.each_with_index.filter_map do |child, index|
        build_node(child, "#{path}.content[#{index}]", depth + 1)
      end
      Node.join_text(nodes)
    end

    def build_marks(marks, path)
      return [] if marks.nil?
      return invalid("marks is not a list", path) || [] unless marks.is_a?(Array)

      built = marks.each_with_index.filter_map { |mark, index| build_mark(mark, "#{path}.marks[#{index}]") }
      built.uniq.sort_by.with_index { |mark, index| [@schema.mark_rank(mark.type), index] }
    end

    def build_mark(hash, path)
      return invalid("not a mark: #{hash.inspect}", path) unless hash.is_a?(Hash)

      name = fetch(hash, "type")
      return invalid("missing mark type", path) unless name.is_a?(String) || name.is_a?(Symbol)

      mark_type = @schema.mark_type(name)
      unless mark_type
        invalid("unknown mark type #{name}", path)
        attrs = fetch(hash, "attrs")
        return Mark.new(type: Naming.snake(name), attrs: attrs.is_a?(Hash) ? attrs.transform_keys(&:to_sym) : {})
      end

      given = fetch(hash, "attrs")
      attrs = mark_type.build_attrs(given, report: reporter(path))
      return invalid("removed #{name} mark", path) unless attrs

      Mark.new(type: mark_type.type_name, attrs: attrs, unknown_attrs: mark_type.unknown_attrs(given))
    end

    def fetch(hash, key)
      hash.key?(key) ? hash[key] : hash[key.to_sym]
    end

    def reporter(path)
      ->(message) { @schema.report(message, path: path) }
    end

    def invalid(message, path)
      @schema.report(message, path: path)
    end
  end
end
