# frozen_string_literal: true

require "test_helper"

class TestHTMLSplitter < Minitest::Test
  def split(html, size: 1) = Prosemirror::HTML::Splitter.new(size).call(html)

  def test_cuts_between_top_level_elements
    assert_equal ["<p>a <b>b</b></p>", "\n<p>c</p>", "<hr>", "d<br/>", "<p>e</p>"],
      split("<p>a <b>b</b></p>\n<p>c</p><hr>d<br/><p>e</p>")
  end

  def test_pieces_have_at_least_the_size
    assert_equal ["<p>a</p><p>b</p>", "<p>c</p>"], split("<p>a</p><p>b</p><p>c</p>", size: 12)
  end

  def test_short_html_is_not_split
    assert_equal ["<p>a</p><p>b</p>"], split("<p>a</p><p>b</p>", size: 100)
  end

  def test_skips_quoted_attributes_comments_and_raw_text
    assert_equal [%(<p title="</p>">a</p>), "<!-- <p> -->", "<script></p><p></script>", "<p>b</p>"],
      split(%(<p title="</p>">a</p><!-- <p> --><script></p><p></script><p>b</p>))
  end

  def test_keeps_the_rest_whole_when_the_structure_is_unclear
    assert_equal ["<p>a</p>", "<ul><li>a<li>b</ul><p>c</p>"], split("<p>a</p><ul><li>a<li>b</ul><p>c</p>")
    assert_equal ["<p>a</p>", "</span><p>b</p>"], split("<p>a</p></span><p>b</p>")
    assert_equal ["<div><p>a</div><p>b</p>"], split("<div><p>a</div><p>b</p>")
  end

  def test_erb_is_not_split
    assert_equal ["<p>a</p><% if x %><p>b</p><% end %>"], split("<p>a</p><% if x %><p>b</p><% end %>")
  end

  def test_imports_the_same_document_in_pieces
    html = "<h2>Title</h2>\n<ul><li>a</li><li>b <b>c</b></li></ul>\ntext <i>more</i><p>é &amp; ü</p><pre> x\n y</pre>"
    whole = Prosemirror.from_html(html).to_h
    splitter = Prosemirror::HTML::Splitter.new(1)

    Prosemirror::HTML::Splitter.stub(:new, ->(_size) { splitter }) do
      assert_equal 5, splitter.call(html).size
      assert_equal whole, Prosemirror.from_html(html).to_h
    end
  end
end
