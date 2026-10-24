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
    # Called with all the URLs of a document at once, before rendering it: returns a Hash from each URL to
    # its rewritten URL, or nil. Instead of `resolve_url`, to look up records in one query.
    prop :resolve_urls, _Callable?, reader: false, predicate: :public
    # Raise `InvalidDocument` instead of fixing invalid documents.
    prop :strict, _Boolean, default: false, reader: false, predicate: :public
    # Called with an `InvalidDocument` error for each problem fixed.
    prop :on_invalid, _Callable?, reader: false

    # Tiptap's StarterKit and common extensions. `text_align: true` adds the TextAlign extension, configured
    # for headings and paragraphs.
    def self.tiptap(text_align: false, **)
      new(
        nodes: [
          Nodes::Doc, text_align ? TextAlign::Paragraph : Nodes::Paragraph, Nodes::Text,
          text_align ? TextAlign::Heading : Nodes::Heading, Nodes::Blockquote, Nodes::BulletList,
          Nodes::OrderedList, Nodes::ListItem, Nodes::CodeBlock, Nodes::HardBreak, Nodes::HorizontalRule,
          Nodes::Image, Nodes::Table, Nodes::TableRow, Nodes::TableHeader, Nodes::TableCell, Nodes::TaskList,
          Nodes::TaskItem, Nodes::Details, Nodes::DetailsSummary, Nodes::DetailsContent, Nodes::Youtube,
          Nodes::Twitch, Nodes::Mention
        ],
        # In Tiptap's order, which sorts and nests marks.
        marks: [
          Marks::Link, Marks::Bold, Marks::Code, Marks::Italic, Marks::Strike, Marks::Underline,
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
        marks: [Marks::Basic::Link, Marks::Basic::Em, Marks::Basic::Strong, Marks::Basic::Code],
        **
      )
    end

    def after_initialize
      @node_lookup = lookup(@nodes)
      @mark_lookup = lookup(@marks)
      @node_names = spellings(@node_lookup)
      @mark_names = spellings(@mark_lookup)
      @textblocks = @nodes.to_h { |type| [type, textblock_type?(type)] }
      @content_matches = @nodes.to_h { |type| [type, ContentMatch.compile(type.content, self)] }
      raise ArgumentError, "the schema has no #{@top_node} node type" unless node_type(@top_node)
      raise ArgumentError, "resolve_url and resolve_urls can't be used together" if @resolve_url && @resolve_urls
    end

    # The start state of a node type's content expression.
    def content_match(type)
      @content_matches.fetch(type)
    end

    # The node types with this name or in this group, in schema order.
    def node_types_named(name)
      @nodes.select { |type| type.type_name == name || type.group.include?(name) }
    end

    # A node of this type, created empty and filled with the content it requires, or nil when its
    # type, or one it requires, has required attributes.
    def create_and_fill(type)
      return nil if type.required_attrs?

      fill = content_match(type).fill_before([], self, to_end: true)
      content = fill&.map { |child| create_and_fill(child) }
      return nil if content.nil? || content.include?(nil)

      Node.new(type: type.type_name, attrs: type.default_attrs, content: content)
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
      @node_names[name] || @node_lookup[Naming.snake(name).to_sym]
    end

    def mark_type(name)
      @mark_names[name] || @mark_lookup[Naming.snake(name).to_sym]
    end

    # Build a document from JSON, given as a Hash or a String.
    def parse(json)
      Document.new(JSONParser.new(self).parse(json), schema: self)
    end

    # Build a document from HTML, with the parse rules of the schema's types. Needs the `herb` gem.
    def parse_html(html)
      Document.new(HTMLParser.new(self).parse(html), schema: self)
    end

    # Build a document from Markdown, with the parse rules of the schema's types. Needs the `commonmarker` gem.
    def parse_markdown(markdown)
      Document.new(HTMLParser.new(self).parse_element(Markdown::Builder.new.call(markdown)), schema: self)
    end

    # Build a document from plain text: blank lines separate paragraphs, and other line breaks become the
    # schema's line break node, like `hard_break`, or spaces without one. Spaces are kept.
    def parse_text(text)
      paragraph = node_type(:paragraph) || @nodes.find { |type| textblock?(type) }
      linebreak = @nodes.find(&:linebreak_replacement?)
      separator = linebreak ? {"type" => linebreak.type_name.to_s} : {"type" => "text", "text" => " "}
      blocks = UTF8.string(text).gsub(/\r\n?/, "\n").split(/\n[ \t]*\n/).map { |block| block.gsub(/\A\n+|\n+\z/, "") }
      content = blocks.reject { |block| block.strip.empty? }.map do |block|
        inline = block.split("\n").each_with_index.flat_map do |line, index|
          [(separator if index.positive?), ({"type" => "text", "text" => line} unless line.empty?)].compact
        end
        {"type" => paragraph.type_name.to_s, "content" => inline}
      end
      parse({"type" => @top_node.to_s, "content" => content.empty? ? [{"type" => paragraph.type_name.to_s}] : content})
    end

    # The type name as written in JSON.
    def json_type_name(name)
      (@case == :camel) ? Naming.camel(name) : name.to_s
    end

    # The set of marks with this mark added, in schema order, as ProseMirror's `Mark#addToSet`: a mark
    # replaces the marks it excludes, and isn't added when a mark of the set excludes it.
    def add_mark(mark, set)
      type = mark_type(mark.type)
      result = []
      placed = false
      set.each do |other|
        return set if other == mark

        other_type = mark_type(other.type)
        next if type.excludes?(other_type)
        return set if other_type.excludes?(type)

        if !placed && mark_rank(other.type) > mark_rank(mark.type)
          result << mark
          placed = true
        end
        result << other
      end
      result << mark unless placed
      result
    end

    # Whether a URL's scheme is allowed, or the URL is relative. Browsers ignore leading control characters
    # and spaces, and tabs and newlines anywhere in a URL.
    # The URLs resolved with `resolve_urls`, as a Hash, or nil without it.
    def resolve_urls(urls)
      return unless @resolve_urls
      return {} if urls.empty?

      @resolve_urls.call(urls).to_h
    end

    def allowed_url?(url)
      return false unless url.is_a?(String)

      normalized = url.delete("\t\n\r").sub(/\A[\x00-\x20]+/, "")
      scheme = normalized[%r{\A([^/?#]*):}, 1]
      return true if scheme.nil?

      scheme.match?(/\A[a-z][a-z\d+.-]*\z/i) && @url_schemes.include?(scheme.downcase)
    end

    # The order of marks in a node. Marks of unknown types come last.
    def mark_rank(name)
      @marks.index(mark_type(name)) || @marks.size
    end

    # Whether nodes of this type contain inline content, like a paragraph.
    def textblock?(type)
      @textblocks.fetch(type, false)
    end

    # The URL after `resolve_url` or `resolve_urls`, when its scheme is allowed. Otherwise nil, and the
    # problem is reported. `resolved_urls` holds URLs already resolved with `resolve_urls`: others are
    # resolved one at a time.
    def safe_url(url, resolved_urls = nil)
      return nil unless url.is_a?(String)

      resolved = resolve(url, resolved_urls)
      unless resolved.is_a?(String)
        return report("URL could not be resolved: #{url.inspect}", error_class: UnresolvedURL, url:)
      end
      return report("URL scheme not allowed: #{resolved.inspect}") unless allowed_url?(resolved)

      resolved.gsub("&", "&amp;")
    end

    # Raise in strict mode, otherwise call `on_invalid`.
    def report(message, path: nil, error_class: InvalidDocument, **details)
      error = error_class.new(message, path:, **details)
      raise error if @strict

      @on_invalid&.call(error)
      nil
    end

    # The document as JSON, as a Hash.
    def serialize(node)
      hash = {"type" => json_type_name(node.type)}
      hash["text"] = node.text if node.text?
      attrs = serialize_node_attrs(node)
      hash["attrs"] = attrs unless attrs.empty?
      hash["content"] = node.content.map { |child| serialize(child) } unless node.content.empty?
      hash["marks"] = node.marks.map { |mark| serialize_mark(mark) } unless node.marks.empty?
      hash
    end

    private

    def resolve(url, resolved_urls)
      return @resolve_url.call(url) if @resolve_url
      return url unless @resolve_urls

      resolved_urls = resolve_urls([url]) unless resolved_urls&.key?(url)
      resolved_urls[url]
    end

    def lookup(types)
      types.each_with_object({}) do |type, table|
        [type.type_name, *type.aliases].each { |name| table[name] ||= type }
        table[type.type_name] = type
      end
    end

    # The names of a lookup table, as Symbols and Strings, in snake_case and camelCase, so that most names
    # are found without converting them.
    def spellings(lookup)
      table = {}
      lookup.each { |name, type| table[name] = table[name.name] = type }
      lookup.each { |name, type| table[Naming.camel(name).freeze] ||= type }
      table.each_key.select { |name| name.is_a?(String) }.each { |name| table[name.to_sym] ||= table[name] }
      table.freeze
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

    # Declared attributes with their JSON names, then the unknown ones, as they were.
    def serialize_node_attrs(node)
      type = node_type(node.type)
      attrs = type ? type.serialize_attrs(node.attrs) : node.attrs.transform_keys(&:to_s)
      attrs.merge(node.unknown_attrs)
    end

    def serialize_mark(mark)
      hash = {"type" => json_type_name(mark.type)}
      type = mark_type(mark.type)
      attrs = type ? type.serialize_attrs(mark.attrs) : mark.attrs.transform_keys(&:to_s)
      attrs = attrs.merge(mark.unknown_attrs)
      hash["attrs"] = attrs unless attrs.empty?
      hash
    end
  end
end
