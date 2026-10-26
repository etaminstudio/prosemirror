# frozen_string_literal: true

module Prosemirror
  module Marks
    # Tiptap's link. Without an allowed `href`, its text is rendered without a link.
    class Link < MarkType
      priority 1000 # As in Tiptap: the outermost mark.
      prop :href, _String(length: 1..), url: true
      prop :target, _String?
      prop :rel, _String?
      prop :css_class, _String?, json: "class"
      prop :title, _String?
      parse_html(tag: "a[href]") { |element, schema| schema.allowed_url?(element["href"]) && {} }

      markdown(**MarkdownSerializer::LINK)

      def view_template(&)
        href = safe_url(@href)
        return yield unless href

        a(href: href, target: attribute_text(@target), rel: attribute_text(@rel), class: attribute_text(@css_class),
          title: attribute_text(@title), &)
      end
    end
  end
end
