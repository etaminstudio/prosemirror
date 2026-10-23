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

    # The document as HTML. The string is `html_safe` when ActiveSupport is loaded.
    def to_html
      html = to_component.call
      html.respond_to?(:html_safe) ? html.html_safe : html
    end

    # A Phlex component rendering the document, to render it inside another component:
    #
    #   render doc.to_component
    def to_component
      HTMLRenderer.new(self)
    end

    # The document as plain text, with blocks separated by `block_separator`.
    def to_text(block_separator: "\n\n")
      TextSerializer.new(schema, block_separator: block_separator).call(root)
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

    def ==(other)
      other.is_a?(Document) && root == other.root
    end
    alias_method :eql?, :==

    def hash
      root.hash
    end
  end
end
