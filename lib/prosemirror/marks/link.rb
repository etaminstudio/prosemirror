# frozen_string_literal: true

module Prosemirror
  module Marks
    # Tiptap's link. Without an allowed `href`, its text is rendered without a link.
    class Link < MarkType
      prop :href, _String(length: 1..)
      prop :target, _String?
      prop :rel, _String?
      prop :css_class, _String?, json: "class"
      prop :title, _String?

      def view_template(&)
        href = safe_url(@href)
        return yield unless href

        a(href: href, target: @target, rel: @rel, class: @css_class, title: @title, &)
      end
    end
  end
end
