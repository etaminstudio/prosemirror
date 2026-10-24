# frozen_string_literal: true

module Prosemirror
  # Renders a document to HTML. Use `doc.to_phlex` to render it inside another Phlex component:
  #
  #   render doc.to_phlex
  class HTMLRenderer < Phlex::HTML
    include Rendering

    def initialize(document)
      super()
      @document = document
      @_prosemirror_schema = document.schema
    end

    # The document's URLs are resolved at once, with the schema's `resolve_urls`, for each rendering.
    def view_template
      @_prosemirror_urls = prosemirror_schema.resolve_urls(@document.urls) if prosemirror_schema.resolve_urls?
      render_content([@document.root])
    end
  end
end
