# frozen_string_literal: true

module Prosemirror
  # Renders a document to HTML. Use `doc.to_phlex` to render it inside another Phlex component:
  #
  #   render doc.to_phlex
  class HTMLRenderer < Phlex::HTML
    include Rendering

    def initialize(document, heading_ids: false)
      super()
      @document = document
      @heading_ids = heading_ids
      @_prosemirror_schema = document.schema
    end

    # The document's URLs are resolved at once, with the schema's `resolve_urls`, for each rendering, and so
    # are its heading ids, which need the whole document to be unique.
    def view_template
      @_prosemirror_urls = prosemirror_schema.resolve_urls(@document.urls) if prosemirror_schema.resolve_urls?
      @_prosemirror_heading_ids = @document.heading_ids if @heading_ids
      render_content([@document.root])
    end
  end
end
