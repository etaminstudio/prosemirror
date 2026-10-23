# frozen_string_literal: true

module Prosemirror
  # Renders a document to HTML. Use `doc.to_component` to render it inside another Phlex component:
  #
  #   render doc.to_component
  class HTMLRenderer < Phlex::HTML
    include Rendering

    def initialize(document)
      super()
      @document = document
      @_prosemirror_schema = document.schema
    end

    def view_template
      render_content([@document.root])
    end
  end
end
