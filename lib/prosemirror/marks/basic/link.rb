# frozen_string_literal: true

module Prosemirror
  module Marks
    module Basic
      # ProseMirror's link. Without an allowed `href`, its text is rendered without a link.
      class Link < MarkType
        prop :href, _String(length: 1..)
        prop :title, _String?
        parse_html(tag: "a[href]") { |element, schema| schema.allowed_url?(element["href"]) && {} }

        markdown(**MarkdownSerializer::LINK)

        def view_template(&)
          href = safe_url(@href)
          return yield unless href

          a(href: href, title: @title, &)
        end
      end
    end
  end
end
