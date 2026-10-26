# frozen_string_literal: true

module Prosemirror
  # A document and its schema. Enumerating a document yields all its nodes, depth first.
  #
  #   doc = Prosemirror.parse(json)
  #   doc.to_html
  #   doc.select { |node| node in { type: :heading, attrs: { level: 1 } } }
  class Document
    include Enumerable

    attr_reader :root, :schema

    def initialize(root, schema: Prosemirror.schema)
      @root = root
      @schema = schema
    end

    def content
      root.content
    end

    def each(&)
      root.descendants(&)
    end

    # The URLs in the attributes of its nodes and marks declared with `url: true`, like links' `href` and
    # images' `src`, without duplicates.
    def urls
      each_with_object(Set.new) do |node, urls|
        add_urls(urls, schema.node_type(node.type), node.attrs)
        node.marks.each { |mark| add_urls(urls, schema.mark_type(mark.type), mark.attrs) }
      end.to_a
    end

    # The document as HTML. The string is `html_safe` when ActiveSupport is loaded.
    def to_html
      html = to_phlex.call
      html.respond_to?(:html_safe) ? html.html_safe : html
    end

    # A Phlex component rendering the document, to render it inside another Phlex component:
    #
    #   render doc.to_phlex
    def to_phlex
      HTMLRenderer.new(self)
    end

    # Lets Rails render the document in ERB templates and ViewComponents: `<%= render doc %>`.
    def render_in(_view_context, &)
      to_html
    end

    # The document as plain text, with blocks separated by `block_separator`.
    def to_text(block_separator: "\n\n")
      TextSerializer.new(schema, block_separator: block_separator).call(root)
    end

    # The document as Markdown (GitHub Flavored Markdown for tables and strikethrough). Formatting Markdown
    # has no syntax for, like underline, keeps only its text, or is written as HTML with `html: true`.
    def to_markdown(html: false)
      MarkdownSerializer.new(schema, html: html).call(root)
    end

    # The document as JSON, as a Hash.
    def to_h
      schema.serialize(root)
    end

    def as_json(*)
      to_h
    end

    def to_json(*)
      to_h.to_json(*)
    end

    def text_content
      root.text_content
    end

    # A new document built from a block called with each node, children first. The block returns the node
    # to keep, another node, an array of nodes to put in its place, or nil to remove it:
    #
    #   doc.transform do |node|
    #     case node
    #     in { type: :paragraph } if node.blank? then nil
    #     in { type: :heading, attrs: { level: 1 } } then node.with(attrs: { level: 2 })
    #     else node
    #     end
    #   end
    #
    # Adjacent text nodes with the same marks are joined. When a node's content changed and lacks what its
    # content expression requires, the required nodes are added and reported with `on_invalid`.
    def transform(&)
      Document.new(Transformer.new(schema, &).call(root), schema: schema)
    end

    # A shorter document, for previews: about `length` characters of text, cut at the end of a word, with
    # `omission` after it. It keeps its structure: the marks and blocks the text is in, and what comes before
    # the cut. What comes after is left out. The document itself when its text is short enough.
    #
    #   doc.truncate(200).to_html # => "<p>The first <strong>words</strong>…</p>"
    def truncate(length, omission: "…")
      cut_index, cut_text = cut(length)
      return self unless cut_index

      seen = 0
      content = Transformer.new(schema, report: false) do |node|
        if node.text?
          seen += 1
          if seen - 1 < cut_index then node
          elsif seen - 1 == cut_index then node.with(text: cut_text + omission)
          end
        elsif seen > cut_index && (node.content.empty? || schema.node_type(node.type)&.leaf?)
          nil
        else
          node
        end
      end.call(root)
      Document.new(content, schema: schema)
    end

    # Raises InvalidDocument for the first problem with the schema: an unknown node or mark type, invalid
    # attributes, content that doesn't match a content expression, or marks a node doesn't allow. Returns
    # the document.
    def check
      Checker.new(schema).call(root)
      self
    end

    def valid?
      check
      true
    rescue InvalidDocument
      false
    end

    def ==(other)
      other.is_a?(Document) && root == other.root
    end
    alias_method :eql?, :==

    def hash
      root.hash
    end

    private

    # Where to cut the text to keep about `length` characters, at the end of a word: the index of the last
    # text node to keep, and its kept text, without trailing spaces and punctuation. Nil when the text is
    # short enough. A first word longer than `length` is cut inside it.
    def cut(length)
      texts = select(&:text?)
      remaining = length
      texts.each_with_index do |node, index|
        text = node.text
        if text.length <= remaining
          remaining -= text.length
          next unless remaining.zero? && index < texts.size - 1

          return [index, trim_end(text)]
        end

        word_end = text[0, remaining + 1].rindex(/\s/)
        kept = word_end ? trim_end(text[0, word_end]) : ""
        return [index, kept] unless kept.empty?
        return [index, text[0, remaining]] if index.zero?

        return [index - 1, trim_end(texts[index - 1].text)]
      end
      nil
    end

    def trim_end(text) = text.sub(/[[:space:][:punct:]]+\z/, "")

    def add_urls(urls, type, attrs)
      type&.url_attributes&.each do |name|
        value = attrs[name]
        urls << value if value.is_a?(String)
      end
    end
  end
end
