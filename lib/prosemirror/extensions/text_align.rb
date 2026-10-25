# frozen_string_literal: true

module Prosemirror
  # Tiptap extensions that add attributes to existing types, rather than types of their own.
  module Extensions
    # Tiptap's TextAlign extension: a `textAlign` attribute, rendered as a `text-align` style. Included in the
    # paragraphs and headings of `Schema.tiptap(text_align: true)`. A custom type includes it, and renders
    # `style: text_align_style`.
    module TextAlign
      ALIGNMENTS = %w[left center right justify].freeze

      def self.included(type)
        # From the `text-align` style, or the old `align` attribute, which Tiptap doesn't read.
        type.prop :text_align, type._Union?(*ALIGNMENTS), json: "textAlign", parse_html: lambda { |element|
          (element.style["text-align"] || element["align"]).to_s.strip.downcase.then { |value| value if ALIGNMENTS.include?(value) }
        }
      end

      def text_align_style = @text_align && "text-align: #{@text_align}"

      class Paragraph < Nodes::Paragraph
        include TextAlign

        def view_template(&) = p(style: text_align_style, &)
      end

      class Heading < Nodes::Heading
        include TextAlign

        def view_template(&) = tag(:"h#{@level}", style: text_align_style, &)
      end
    end
  end
end
