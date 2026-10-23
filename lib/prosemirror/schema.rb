# frozen_string_literal: true

module Prosemirror
  # A set of node and mark types, with rendering options.
  #
  #   schema = Prosemirror::Schema.tiptap(case: :camel).with(ImageBlock)
  #   schema.parse(json).to_html
  class Schema < Literal::Data
    DEFAULT_URL_SCHEMES = %w[http https mailto tel].freeze

    prop :nodes, _Array(_Class(NodeType)), &Coerce::FROZEN
    prop :marks, _Array(_Class(MarkType)), &Coerce::FROZEN
    prop :top_node, Symbol, default: :doc, &Coerce::SYMBOL
    # `:snake` or `:camel`, for type names in JSON output.
    prop :case, _Union(:snake, :camel), default: :snake, reader: false
    # The URL schemes allowed in links and images. Relative URLs are always allowed.
    prop :url_schemes, _Array(String), default: DEFAULT_URL_SCHEMES do |schemes|
      schemes.map(&:downcase).freeze
    end
    # Called with each URL before it is checked, to rewrite it.
    prop :resolve_url, _Callable?, reader: false
    # Raise `InvalidDocument` instead of fixing invalid documents.
    prop :strict, _Boolean, default: false, reader: false, predicate: :public
    # Called with an `InvalidDocument` error for each problem fixed.
    prop :on_invalid, _Callable?, reader: false

    # Tiptap's StarterKit and common extensions.
    def self.tiptap(**)
      new(
        nodes: [
          Nodes::Doc, Nodes::Paragraph, Nodes::Text, Nodes::Heading, Nodes::Blockquote, Nodes::BulletList,
          Nodes::OrderedList, Nodes::ListItem, Nodes::CodeBlock, Nodes::HardBreak, Nodes::HorizontalRule,
          Nodes::Image, Nodes::Table, Nodes::TableRow, Nodes::TableHeader, Nodes::TableCell
        ],
        marks: [
          Marks::Link, Marks::Bold, Marks::Italic, Marks::Underline, Marks::Strike, Marks::Code,
          Marks::Subscript, Marks::Superscript, Marks::Highlight
        ],
        **
      )
    end

    # ProseMirror's prosemirror-schema-basic and prosemirror-schema-list.
    def self.prosemirror(**)
      new(
        nodes: [
          Nodes::Doc, Nodes::Paragraph, Nodes::Blockquote, Nodes::HorizontalRule, Nodes::Heading,
          Nodes::Basic::CodeBlock, Nodes::Text, Nodes::Basic::Image, Nodes::HardBreak, Nodes::Basic::OrderedList,
          Nodes::BulletList, Nodes::ListItem
        ],
        marks: [Marks::Basic::Link, Marks::Basic::Em, Marks::Basic::Strong, Marks::Code],
        **
      )
    end

    def after_initialize
      @node_lookup = lookup(@nodes)
      @mark_lookup = lookup(@marks)
      @textblocks = @nodes.to_h { |type| [type, textblock_type?(type)] }
      raise ArgumentError, "the schema has no #{@top_node} node type" unless node_type(@top_node)
    end

    # A copy of the schema with other options.
    def with_options(**)
      self.class.new(**to_h, **)
    end

    # A copy of the schema with more types. A type replaces the type with the same name.
    def with(*types)
      nodes = types.select { |type| type.is_a?(Class) && type < NodeType }
      marks = types.select { |type| type.is_a?(Class) && type < MarkType }
      raise ArgumentError, "not a node or mark type" if nodes.size + marks.size != types.size

      self.class.new(**to_h, nodes: merge_types(@nodes, nodes), marks: merge_types(@marks, marks))
    end

    # The node type for a name, alias, or camelCase name.
    def node_type(name)
      @node_lookup[Naming.snake(name).to_sym]
    end

    def mark_type(name)
      @mark_lookup[Naming.snake(name).to_sym]
    end

    # Build a document from JSON, given as a Hash or a String.
    def parse(json)
      Document.new(JSONParser.new(self).parse(json), schema: self)
    end

    # The type name as written in JSON.
    def json_type_name(name)
      @case == :camel ? Naming.camel(name) : name.to_s
    end

    # The order of marks in a node. Marks of unknown types come last.
    def mark_rank(name)
      @marks.index(mark_type(name)) || @marks.size
    end

    # Whether nodes of this type contain inline content, like a paragraph.
    def textblock?(type)
      @textblocks.fetch(type, false)
    end

    # The URL after `resolve_url`, when its scheme is allowed. Otherwise nil.
    def safe_url(url)
      url = @resolve_url.call(url) if @resolve_url && url
      return nil unless url.is_a?(String)
      return url.gsub("&", "&amp;") if allowed_url?(url)

      report("URL scheme not allowed: #{url.inspect}")
      nil
    end

    # Raise in strict mode, otherwise call `on_invalid`.
    def report(message, path: nil)
      error = InvalidDocument.new(message, path: path)
      raise error if @strict

      @on_invalid&.call(error)
      nil
    end

    # The document as JSON, as a Hash.
    def serialize(node)
      hash = { "type" => json_type_name(node.type) }
      hash["text"] = node.text if node.text?
      attrs = serialize_node_attrs(node)
      hash["attrs"] = attrs unless attrs.empty?
      hash["content"] = node.content.map { |child| serialize(child) } unless node.content.empty?
      hash["marks"] = node.marks.map { |mark| serialize_mark(mark) } unless node.marks.empty?
      hash
    end

    private

    def lookup(types)
      types.each_with_object({}) do |type, table|
        [type.type_name, *type.aliases].each { |name| table[name] ||= type }
        table[type.type_name] = type
      end
    end

    def merge_types(types, additions)
      additions.reduce(types) do |list, addition|
        index = list.index { |type| type.type_name == addition.type_name }
        index ? list.dup.tap { |copy| copy[index] = addition } : list + [addition]
      end
    end

    def textblock_type?(type)
      return false if type.leaf?

      type.content.names.any? do |name|
        name == :text || name == :inline || node_types_named(name).any?(&:inline?)
      end
    end

    def node_types_named(name)
      @nodes.select { |type| type.type_name == name || type.group.include?(name) }
    end

    # Browsers ignore leading control characters and spaces, and tabs and newlines anywhere in a URL.
    def allowed_url?(url)
      normalized = url.delete("\t\n\r").sub(/\A[\x00-\x20]+/, "")
      scheme = normalized[%r{\A([^/?#]*):}, 1]
      return true if scheme.nil?

      scheme.match?(/\A[a-z][a-z\d+.-]*\z/i) && @url_schemes.include?(scheme.downcase)
    end

    def serialize_node_attrs(node)
      type = node_type(node.type)
      type ? type.serialize_attrs(node.attrs) : node.attrs.transform_keys(&:to_s)
    end

    def serialize_mark(mark)
      hash = { "type" => json_type_name(mark.type) }
      type = mark_type(mark.type)
      attrs = type ? type.serialize_attrs(mark.attrs) : mark.attrs.transform_keys(&:to_s)
      hash["attrs"] = attrs unless attrs.empty?
      hash
    end
  end
end
