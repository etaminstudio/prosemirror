# frozen_string_literal: true

module Prosemirror
  # Builds nodes from ProseMirror JSON, and normalizes them as ProseMirror does:
  # marks sorted in schema order, adjacent text with the same marks joined, empty text removed.
  # Invalid parts are fixed and reported to the schema (which raises in strict mode).
  # @api private
  class JSONParser
    MAX_DEPTH = 100
    EMPTY = [].freeze

    def initialize(schema)
      @schema = schema
      # The path of the node being built, as `["doc", :content, 0, :marks, 1]`: a string is only made for
      # a report.
      @path = []
      @report = ->(message) { invalid(message) }
    end

    def parse(json)
      # Frozen strings go into nodes without being copied.
      hash = json.is_a?(String) ? JSON.parse(json, max_nesting: (MAX_DEPTH * 2) + 2, freeze: true) : json
      raise ArgumentError, "expected a Hash or a JSON String, got #{json.class}" unless hash.is_a?(Hash)

      @path = ["doc"]
      root = build_node(hash, 0) || Node.new(type: @schema.top_node)
      return root if root.type == @schema.top_node

      invalid("the top node is #{root.type}, not #{@schema.top_node}")
      Node.new(type: @schema.top_node, content: [root])
    rescue JSON::NestingError
      raise TooDeep, "the document is nested more than #{MAX_DEPTH} levels deep"
    end

    private

    def build_node(hash, depth)
      return invalid("not a node: #{hash.inspect}") unless hash.is_a?(Hash)
      return invalid("nested more than #{MAX_DEPTH} levels deep") if depth > MAX_DEPTH

      name = fetch(hash, "type")
      return invalid("missing node type") unless name.is_a?(String) || name.is_a?(Symbol)
      return build_text(hash) if name == "text" || name == :text

      node_type = @schema.node_type(name)
      return build_unknown(hash, name, depth) unless node_type

      given = fetch(hash, "attrs")
      attrs = node_type.build_attrs(given, report: @report)
      return invalid("removed #{name} node") unless attrs

      Node.new(type: node_type.type_name, attrs: attrs.freeze, unknown_attrs: node_type.unknown_attrs(given).freeze,
        content: build_content(hash, depth), marks: build_marks(fetch(hash, "marks")))
    end

    def build_text(hash)
      text = fetch(hash, "text")
      return invalid("text node without text") unless text.is_a?(String)
      return nil if text.empty?

      Node.new(type: :text, text: text, marks: build_marks(fetch(hash, "marks")))
    end

    def build_unknown(hash, name, depth)
      invalid("unknown node type #{name}")
      attrs = fetch(hash, "attrs")
      Node.new(type: Naming.snake(name), attrs: attrs.is_a?(Hash) ? attrs.transform_keys(&:to_sym) : {},
        content: build_content(hash, depth), marks: build_marks(fetch(hash, "marks")))
    end

    def build_content(hash, depth)
      content = fetch(hash, "content")
      return EMPTY if content.nil?
      return invalid("content is not a list") || EMPTY unless content.is_a?(Array)

      nodes = []
      content.each_with_index do |child, index|
        @path.push(:content, index)
        node = build_node(child, depth + 1)
        @path.pop
        @path.pop
        nodes << node if node
      end
      Node.join_text(nodes).freeze
    end

    def build_marks(marks)
      return EMPTY if marks.nil?
      return invalid("marks is not a list") || EMPTY unless marks.is_a?(Array)

      built = []
      marks.each_with_index do |mark, index|
        @path.push(:marks, index)
        mark = build_mark(mark)
        @path.pop
        @path.pop
        built << mark if mark
      end
      sort_marks(built).freeze
    end

    # The marks without duplicates, in schema order. Most sets have one mark, or are already sorted.
    def sort_marks(marks)
      return marks if marks.size < 2

      marks = marks.uniq
      ranks = marks.map { |mark| @schema.mark_rank(mark.type) }
      return marks if ranks.each_cons(2).all? { |a, b| a <= b }

      marks.each_with_index.sort_by { |mark, index| [ranks[index], index] }.map(&:first)
    end

    def build_mark(hash)
      return invalid("not a mark: #{hash.inspect}") unless hash.is_a?(Hash)

      name = fetch(hash, "type")
      return invalid("missing mark type") unless name.is_a?(String) || name.is_a?(Symbol)

      mark_type = @schema.mark_type(name)
      unless mark_type
        invalid("unknown mark type #{name}")
        attrs = fetch(hash, "attrs")
        return Mark.new(type: Naming.snake(name), attrs: attrs.is_a?(Hash) ? attrs.transform_keys(&:to_sym) : {})
      end

      given = fetch(hash, "attrs")
      attrs = mark_type.build_attrs(given, report: @report)
      return invalid("removed #{name} mark") unless attrs

      Mark.new(type: mark_type.type_name, attrs: attrs.freeze, unknown_attrs: mark_type.unknown_attrs(given).freeze)
    end

    def fetch(hash, key)
      hash.key?(key) ? hash[key] : hash[key.to_sym]
    end

    # The path as written in reports: `doc.content[0].marks[1]`.
    def path
      ([@path.first] + @path.drop(1).each_slice(2).map { |name, index| "#{name}[#{index}]" }).join(".")
    end

    def invalid(message)
      @schema.report(message, path: path)
    end
  end
end
