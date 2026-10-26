# frozen_string_literal: true

require "test_helper"

class TestTruncate < Minitest::Test
  include TestHelpers

  def document
    Prosemirror.parse(doc(
      {"type" => "heading", "attrs" => {"level" => 2}, "content" => [text("Title here")]},
      paragraph(text("The first "), text("bold words", [{"type" => "bold"}]), text(" of a long, long paragraph.")),
      {"type" => "bulletList", "content" => [{"type" => "listItem", "content" => [paragraph(text("item one"))]}]},
      {"type" => "image", "attrs" => {"src" => "/a.png"}}
    ))
  end

  def truncated(length, **) = document.truncate(length, **).to_html

  # The text is cut at the end of a word, without trailing punctuation, inside the marks and blocks it's in.
  def test_cut_at_the_end_of_a_word
    assert_equal "<h2>Title here</h2><p>The first <strong>bold words</strong> of a long…</p>", truncated(44)
    assert_equal "<h2>Title here</h2><p>The first <strong>bold…</strong></p>", truncated(25)
  end

  # A block isn't started for less than one of its words: the cut moves back to the end of the previous one.
  def test_blocks_after_the_cut_are_left_out
    assert_equal "<h2>Title here</h2><p>The first <strong>bold words</strong> of a long, long paragraph…</p>", truncated(60)
  end

  def test_short_documents_are_kept
    short = document

    assert_same short, short.truncate(1000)
  end

  def test_first_word_longer_than_the_length
    assert_equal "<h2>Tit…</h2>", truncated(3)
  end

  def test_omission
    assert_equal "<h2>Title [more]</h2>", truncated(5, omission: " [more]")
    assert_equal "Title", document.truncate(5, omission: "").to_text
  end

  # Content the schema requires is added back, without reporting it: truncating is expected to remove it.
  def test_result_is_valid
    reported = []
    schema = Prosemirror::Schema.tiptap(on_invalid: ->(error) { reported << error })
    details = doc({"type" => "details", "content" => [
      {"type" => "detailsSummary", "content" => [text("Summary text")]},
      {"type" => "detailsContent", "content" => [paragraph(text("Hidden content"))]}
    ]})
    result = schema.parse(details).truncate(7)

    assert_predicate result, :valid?
    assert_equal "Summary…", result.to_text.lines.first.chomp
    assert_empty reported
  end
end
