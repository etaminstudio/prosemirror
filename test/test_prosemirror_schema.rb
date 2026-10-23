# frozen_string_literal: true

require "test_helper"

class TestProsemirrorSchema < Minitest::Test
  include TestHelpers

  def schema = Prosemirror::Schema.prosemirror

  def test_basic_marks
    json = doc(paragraph(text("x", [{"type" => "strong"}, {"type" => "em"}, {"type" => "code"}])))

    assert_equal "<p><em><strong><code>x</code></strong></em></p>", render(json, schema: schema)
  end

  def test_accepts_tiptap_names
    json = doc(paragraph(text("x", [{"type" => "bold"}])),
      {"type" => "orderedList", "attrs" => {"start" => 2},
       "content" => [{"type" => "listItem", "content" => [paragraph(text("y"))]}]})
    document = Prosemirror.parse(json, schema: schema)

    assert_equal '<p><strong>x</strong></p><ol start="2"><li><p>y</p></li></ol>', document.to_html
    assert_equal({"order" => 2}, document.to_h.dig("content", 1, "attrs"))
    assert_equal "strong", document.to_h.dig("content", 0, "content", 0, "marks", 0, "type")
  end

  def test_inline_image
    json = doc(paragraph(text("a "), {"type" => "image", "attrs" => {"src" => "/a.png", "alt" => "A"}}))

    assert_equal '<p>a <img src="/a.png" alt="A"></p>', render(json, schema: schema)
  end

  def test_code_block_without_attributes
    json = doc({"type" => "code_block", "attrs" => {"params" => "ruby"}, "content" => [text("x")]})
    document = Prosemirror.parse(json, schema: schema)

    assert_equal "<pre><code>x</code></pre>", document.to_html
    assert_nil document.to_h.dig("content", 0, "attrs")
  end

  def test_link_with_title
    json = doc(paragraph(text("x", [{"type" => "link", "attrs" => {"href" => "/", "title" => "Home"}}])))

    assert_equal '<p><a href="/" title="Home">x</a></p>', render(json, schema: schema)
  end

  def test_has_no_tiptap_only_types
    json = doc({"type" => "table", "content" => []}, paragraph(text("x", [{"type" => "underline"}])))

    assert_equal "<p>x</p>", Prosemirror.parse(json, schema: schema.with_options(on_invalid: ->(_) {})).to_html
  end
end
