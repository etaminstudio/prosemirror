# frozen_string_literal: true

require "test_helper"

# The parse rule options and element helpers that custom types use, documented in TYPES.md.
class TestHTMLParseRules < Minitest::Test
  def node_type(name, **options, &)
    Class.new(Prosemirror::NodeType) do
      type_name name
      group(*options.fetch(:group, [:block]))
      expression = options.fetch(:content, "inline*")
      content expression if expression
      class_eval(&) if block_given?
    end
  end

  def mark_type(name, &)
    Class.new(Prosemirror::MarkType) do
      type_name name
      class_eval(&)
    end
  end

  def import(html, *types) = Prosemirror.from_html(html, schema: Prosemirror::Schema.tiptap.with(*types)).to_h["content"]

  def types(content) = content.map { |node| node["type"] }

  # Context

  def test_context_directly_in_a_node
    quote_paragraph = node_type(:quote_paragraph) { parse_html tag: "p", context: "blockquote/", priority: 60 }

    content = import("<blockquote><p>q</p></blockquote><p>p</p>", quote_paragraph)

    assert_equal ["quote_paragraph"], types(content[0]["content"])
    assert_equal "paragraph", content[1]["type"]
  end

  # A list item starts with a paragraph: the rules below match a later one, where a block fits.
  def test_context_anywhere_inside_a_node
    deep = node_type(:deep) { parse_html tag: "p.x", context: "blockquote//", priority: 60 }

    item = import("<blockquote><ul><li><p>a</p><p class=\"x\">b</p></li></ul></blockquote><ul><li><p>a</p><p class=\"x\">c</p></li></ul>", deep)

    assert_equal %w[paragraph deep], types(item.dig(0, "content", 0, "content", 0, "content"))
    assert_equal %w[paragraph paragraph], types(item.dig(1, "content", 0, "content"))
  end

  def test_context_with_several_parents_and_alternatives
    special = node_type(:special) { parse_html tag: "p.x", context: "blockquote/ | ordered_list/list_item/", priority: 60 }

    content = import("<ul><li><p>a</p><p class=\"x\">b</p></li></ul><ol><li><p>a</p><p class=\"x\">c</p></li></ol>" \
      "<blockquote><p class=\"x\">d</p></blockquote>", special)

    assert_equal %w[paragraph paragraph], types(content.dig(0, "content", 0, "content"))
    assert_equal %w[paragraph special], types(content.dig(1, "content", 0, "content"))
    assert_equal %w[special], types(content.dig(2, "content"))
  end

  def test_context_with_a_group
    in_list = node_type(:in_list) { parse_html tag: "p.x", context: "list//", priority: 60 }

    assert_equal %w[paragraph in_list], types(import("<ul><li><p>a</p><p class=\"x\">b</p></li></ul>", in_list).dig(0, "content", 0, "content"))
  end

  # Content

  def test_content_element
    figure = node_type(:figure) { parse_html tag: "figure", content_element: "figcaption" }

    content = import("<figure><img src='/a.png'><figcaption>Caption</figcaption></figure>", figure)

    assert_equal [{"type" => "figure", "content" => [{"type" => "text", "text" => "Caption"}]}], content
  end

  def test_content_element_as_a_block
    figure = node_type(:figure) { parse_html tag: "figure", content_element: ->(element) { element.element_children.last } }

    assert_equal "Caption", import("<figure><b>x</b><span>Caption</span></figure>", figure).dig(0, "content", 0, "text")
  end

  def test_get_content
    stamp = node_type(:stamp) do
      parse_html tag: "time", get_content: ->(element, _schema) { [Prosemirror::Node.new(type: :text, text: element["datetime"])] }
    end

    assert_equal "2026-10-23", import("<time datetime='2026-10-23'>yesterday</time>", stamp).dig(0, "content", 0, "text")
  end

  def test_close_parent
    breaker = node_type(:breaker, content: nil) { parse_html tag: "span.break", close_parent: true }

    content = import("<blockquote><p>a<span class='break'></span>b</p></blockquote>", breaker)

    assert_equal [{"type" => "paragraph", "content" => [{"type" => "text", "text" => "a"}]}, {"type" => "paragraph", "content" => [{"type" => "text", "text" => "b"}]}],
      content.dig(0, "content")
  end

  def test_ignore_and_skip
    ignored = node_type(:ignored) { parse_html tag: "aside", ignore: true }
    skipped = node_type(:skipped) { parse_html tag: "section", skip: true }

    content = import("<aside>hidden</aside><section><h2>t</h2></section>", ignored, skipped)

    assert_equal [{"type" => "heading", "attrs" => {"level" => 2}, "content" => [{"type" => "text", "text" => "t"}]}], content
  end

  def test_priority_and_consuming
    shout = mark_type(:shout) { parse_html tag: "strong", priority: 60, consuming: false }

    marks = import("<p><strong>a</strong></p>", shout).dig(0, "content", 0, "marks")

    assert_equal %w[bold shout], marks.map { |mark| mark["type"] }.sort
  end

  def test_preserve_whitespace
    verse = node_type(:verse) { parse_html tag: "div.verse", preserve_whitespace: :full }
    spaced = node_type(:spaced) { parse_html tag: "div.spaced", preserve_whitespace: true }

    content = import(%(<div class="verse">a  b\nc</div><div class="spaced">a  b\nc</div>), verse, spaced)

    assert_equal [{"type" => "text", "text" => "a  b\nc"}], content.dig(0, "content")
    # Without `:full`, newlines become the schema's line break node, where it fits.
    assert_equal [{"type" => "text", "text" => "a  b"}, {"type" => "hard_break"}, {"type" => "text", "text" => "c"}],
      content.dig(1, "content")
  end

  def test_line_breaks_in_preserved_whitespace
    content = import("<pre>a<br>b</pre>")

    assert_equal "a\nb", content.dig(0, "content", 0, "text")
  end

  def test_erb_in_attribute_values
    assert_equal "/users/<%= id %>", import(%(<p><a href="/users/<%= id %>">u</a></p>)).dig(0, "content", 0, "marks", 0, "attrs", "href")
  end

  # Content expressions

  def test_optional_and_counted_content
    card = node_type(:card, content: "card_title? card_line{2}") { parse_html tag: "div.card" }
    title = node_type(:card_title, group: []) { parse_html tag: "h6", priority: 60 }
    line = node_type(:card_line, group: []) { parse_html tag: "span.line" }

    content = import(%(<div class="card"><span class="line">a</span></div><div class="card"><h6>t</h6><span class="line">a</span><span class="line">b</span><span class="line">c</span></div>),
      card, title, line)

    assert_equal %w[card_line card_line], types(content[0]["content"])
    assert_equal %w[card_title card_line card_line], types(content[1]["content"])
  end

  # Marks

  def test_excludes_by_name_and_group
    plain = mark_type(:plain) do
      excludes "bold color"
      parse_html tag: "kbd"
    end
    red = mark_type(:red) do
      group :color
      parse_html tag: "font"
    end

    marks = import("<p><b><font><kbd>k</kbd></font></b></p>", plain, red).dig(0, "content", 0, "marks")

    assert_equal ["plain"], marks.map { |mark| mark["type"] }
  end

  def test_allowed_marks_by_name
    caption = node_type(:caption) do
      marks "italic"
      parse_html tag: "figcaption"
    end

    marks = import("<figcaption><b><i>x</i></b></figcaption>", caption).dig(0, "content", 0, "marks")

    assert_equal [{"type" => "italic"}], marks
  end

  def test_all_marks_allowed
    note = node_type(:note, content: "text*") do
      marks "_"
      parse_html tag: "aside"
    end

    marks = import("<aside><b>x</b></aside>", note).dig(0, "content", 0, "marks")

    assert_equal [{"type" => "bold"}], marks
  end

  # Selectors and elements

  def test_selectors
    element = Prosemirror::HTML::Element.new("a", {"id" => "main", "href" => "https://x.com/a.pdf", "rel" => "nofollow noopener", "lang" => "en-GB", "class" => "x y"})

    %w[a * #main .x .x.y [href] [rel~=noopener] [lang|=en] [href^=https] [href$=".pdf"] [href*="x.com"] [id=main] a:not(.z) p,a].each do |selector|
      assert element.matches?(selector), selector
    end
    %w[p #other .z [rel~=noop] [lang|=e] [id=mai] a:not(.x)].each do |selector|
      refute element.matches?(selector), selector
    end
  end

  def test_selectors_with_combinators_are_rejected
    assert_raises(ArgumentError) { Prosemirror::HTML::Element.new("p").matches?("div > p") }
    assert_raises(ArgumentError) { Prosemirror::ParseRule.new(type: Prosemirror::Nodes::Paragraph, tag: "div p") }
  end

  def test_element_helpers
    root = Prosemirror::HTML::Builder.new.call(%(<figure id="f"><img src="/a.png"> <figcaption>Cap <b>tion</b></figcaption></figure>))
    figure = root.first_element_child

    assert_equal "figure", figure.name
    assert_equal %w[img figcaption], figure.element_children.map(&:name)
    assert_equal "Cap tion", figure.query("figcaption").text_content
    assert_equal "/a.png", figure.query("img")["src"]
    assert_nil figure.query("video")
    assert_equal figure, figure.query("img").parent
    assert figure.key?("id")
  end
end
