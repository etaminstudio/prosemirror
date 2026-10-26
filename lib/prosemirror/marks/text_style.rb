# frozen_string_literal: true

module Prosemirror
  module Marks
    # Tiptap's TextStyle, with the attributes of its TextStyleKit: Color, BackgroundColor, FontFamily, FontSize
    # and LineHeight, each rendered as a CSS property of a span. Not in `Schema.tiptap`, as in Tiptap's
    # StarterKit: add it with `Schema.tiptap.with(Prosemirror::Marks::TextStyle)`.
    #
    # Unlike Tiptap, a span without any of these properties gets no mark, and a missing property is nil rather
    # than "". Values that could load or run something, like `url()`, are invalid.
    class TextStyle < MarkType
      priority 101 # As in Tiptap: right after links.
      # CSS values without `url()`, `expression()`, escapes or comments, nor `;` or braces that would end the
      # declaration.
      VALUE = %r{\A(?!.*(?:url\s*\(|expression\s*\(|\\|/\*))[\w\s#%.,'"()+-]+\z}im
      # Property names, and the CSS property each one renders.
      PROPERTIES = {
        color: "color", background_color: "background-color", font_family: "font-family",
        font_size: "font-size", line_height: "line-height"
      }.freeze

      PROPERTIES.each do |name, property|
        prop name, _String?(VALUE), json: Naming.camel(name), parse_html: ->(element) { TextStyle.style_of(element, property) }
      end

      parse_html(tag: "span[style]", consuming: false) do |element|
        styled = PROPERTIES.each_value.any? { |property| style_of(element, property) }
        styled ? {} : false
      end

      def view_template(&)
        styles = PROPERTIES.filter_map do |name, property|
          value = instance_variable_get(:"@#{name}")
          "#{property}: #{value}" if value
        end
        styles.empty? ? yield : span(style: styles.join("; "), &)
      end

      # The property in the span's style, or in the spans around it, whose styles Tiptap merges into the
      # innermost one. Colors lose their quotes, as in Tiptap.
      def self.style_of(element, property)
        while element&.element? && element.name == "span"
          value = element.style[property]
          return property.end_with?("color") ? value.delete(%('")) : value if value && !value.empty?

          element = element.parent
        end
      end
    end
  end
end
