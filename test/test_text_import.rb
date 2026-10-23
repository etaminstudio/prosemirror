# frozen_string_literal: true

require "test_helper"

class TestTextImport < Minitest::Test
  def content(text, schema: Prosemirror::Schema.tiptap) = Prosemirror.from_text(text, schema:).to_h["content"]

  def paragraph(*content) = {"type" => "paragraph", "content" => content}

  def text(value) = {"type" => "text", "text" => value}

  def test_blank_lines_separate_paragraphs_and_line_breaks_become_hard_breaks
    assert_equal [paragraph(text("One"), {"type" => "hard_break"}, text("two")), paragraph(text("Three"))],
      content("One\ntwo\n\n\nThree\n")
  end

  def test_spaces_are_kept
    assert_equal [paragraph(text("  a    b "))], content("  a    b ")
  end

  def test_windows_line_endings_and_blank_lines_with_spaces
    assert_equal [paragraph(text("a"), {"type" => "hard_break"}, text("b")), paragraph(text("c"))], content("a\r\nb\r\n \t\r\nc")
  end

  def test_empty_text
    assert_equal [{"type" => "paragraph"}], content("")
    assert_equal [{"type" => "paragraph"}], content("\n\n  \n")
  end

  def test_html_stays_as_text
    assert_equal "<p>a &lt;b&gt;&amp;amp;</p>", Prosemirror.from_text("a <b>&amp;").to_html
  end

  def test_without_a_line_break_type
    schema = Prosemirror::Schema.tiptap.with_options(nodes: Prosemirror::Schema.tiptap.nodes - [Prosemirror::Nodes::HardBreak])

    assert_equal [paragraph(text("a b"))], content("a\nb", schema:)
  end
end
