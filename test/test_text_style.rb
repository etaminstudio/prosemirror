# frozen_string_literal: true

require "test_helper"

class TestTextStyle < Minitest::Test
  include TestHelpers

  def schema(**) = Prosemirror::Schema.tiptap(case: :camel, **).with(Prosemirror::Marks::TextStyle)

  def styled(value, **attrs) = text(value, [{"type" => "textStyle", "attrs" => attrs.transform_keys(&:to_s)}])

  def import(html, schema: self.schema) = Prosemirror.from_html(html, schema:).to_h.dig("content", 0, "content")

  def style_attrs(**attrs) = {"color" => nil, "backgroundColor" => nil, "fontFamily" => nil, "fontSize" => nil, "lineHeight" => nil}.merge(attrs.transform_keys(&:to_s))

  def test_rendering
    document = schema.parse(doc(paragraph(styled("a", color: "#f00", fontFamily: "Inter, sans-serif", fontSize: "18px"), styled("b"))))

    assert_equal %(<p><span style="color: #f00; font-family: Inter, sans-serif; font-size: 18px">a</span>b</p>), document.to_html
  end

  # As Tiptap with TextStyleKit, except that a span without these properties gets no mark, and missing
  # properties are nil rather than "".
  def test_html_import
    html = %(<p><span style="color: red; background-color: yellow; font-family: 'Comic Sans MS'; font-size: 18px; line-height: 1.5">a</span></p>)

    assert_equal [{"type" => "text", "text" => "a", "marks" => [{"type" => "textStyle", "attrs" => style_attrs(color: "red", backgroundColor: "yellow",
      fontFamily: "'Comic Sans MS'", fontSize: "18px", lineHeight: "1.5")}]}], import(html)
    assert_equal [{"type" => "text", "text" => "b", "marks" => [{"type" => "bold"}]}], import(%(<p><span style="font-weight: bold">b</span></p>))
  end

  # Tiptap merges the styles of nested spans into the innermost one.
  def test_nested_spans
    assert_equal style_attrs(color: "red", fontSize: "20px"),
      import(%(<p><span style="color: red"><span style="font-size: 20px">a</span></span></p>)).dig(0, "marks", 0, "attrs")
  end

  # Values that could load or run something, or end the declaration, are invalid: reported and dropped.
  def test_unsafe_values
    reported = []
    document = schema(on_invalid: ->(error) { reported << error.message }).parse(doc(paragraph(
      styled("a", color: "red; background: url(https://example.com/pixel)", fontFamily: "x\\26 y", backgroundColor: "expression(alert(1))", fontSize: "12px")
    )))

    assert_equal %(<p><span style="font-size: 12px">a</span></p>), document.to_html
    assert_equal 3, reported.size
  end

  def test_after_link_as_in_tiptap
    html = %(<p><strong><span style="color: red"><a href="/x">a</a></span></strong></p>)

    assert_equal %w[link textStyle bold], import(html).dig(0, "marks").map { |mark| mark["type"] }
  end

  def test_markdown
    document = schema.parse(doc(paragraph(styled("a", color: "red"))))

    assert_equal "a\n", document.to_markdown
    assert_equal %(<span style="color: red">a</span>\n), document.to_markdown(html: true)
  end

  # Without the option, styled spans aren't imported, and the mark is unknown.
  def test_off_by_default
    plain = Prosemirror::Schema.tiptap(case: :camel, on_invalid: ->(_) {})

    assert_equal [{"type" => "text", "text" => "a"}], import(%(<p><span style="color: red">a</span></p>), schema: plain)
    assert_equal "<p>a</p>", plain.parse(doc(paragraph(styled("a", color: "red")))).to_html
  end
end
