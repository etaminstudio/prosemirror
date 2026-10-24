# frozen_string_literal: true

require "test_helper"

class TestTextAlign < Minitest::Test
  include TestHelpers

  def schema(**) = Prosemirror::Schema.tiptap(case: :camel, text_align: true, **)

  def aligned(type, align, **attrs) = {"type" => type, "attrs" => {**attrs, "textAlign" => align}, "content" => [text(type)]}

  def test_rendering
    document = schema.parse(doc(aligned("paragraph", "center"), aligned("heading", "right", "level" => 2), paragraph(text("p"))))

    assert_equal %(<p style="text-align: center">paragraph</p><h2 style="text-align: right">heading</h2><p>p</p>), document.to_html
    assert_equal({"textAlign" => nil}, document.to_h.dig("content", 2, "attrs"))
  end

  # As Tiptap with `TextAlign.configure({ types: ["heading", "paragraph"] })`, and the old `align` attribute.
  def test_html_import
    html = %(<p style="text-align: justify">a</p><h3 style="text-align: center">b</h3><p align="right">c</p><p style="text-align: start">d</p>)

    assert_equal ["justify", "center", "right", nil], Prosemirror.from_html(html, schema:).to_h["content"].map { |node| node.dig("attrs", "textAlign") }
  end

  def test_invalid_alignments_are_dropped
    reported = []
    document = schema(on_invalid: ->(error) { reported << error.message }).parse(doc(aligned("paragraph", "middle")))

    assert_equal "<p>paragraph</p>", document.to_html
    assert_equal ["doc.content[0]: invalid attribute textAlign: \"middle\""], reported
  end

  # Without the option, the attribute is kept, but not rendered.
  def test_off_by_default
    document = Prosemirror::Schema.tiptap(case: :camel).parse(doc(aligned("paragraph", "center")))

    assert_equal "<p>paragraph</p>", document.to_html
    assert_equal({"textAlign" => "center"}, document.to_h.dig("content", 0, "attrs"))
  end

  def test_custom_types
    callout = Class.new(Prosemirror::NodeType) do
      type_name :callout
      group :block
      content "inline*"
      include Prosemirror::TextAlign

      def view_template(&) = aside(style: text_align_style, &)
    end

    assert_equal %(<aside style="text-align: left">callout</aside>), schema.with(callout).parse(doc(aligned("callout", "left"))).to_html
  end
end
