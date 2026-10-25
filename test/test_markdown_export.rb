# frozen_string_literal: true

require "test_helper"

class TestMarkdownExport < Minitest::Test
  include TestHelpers

  def schema = Prosemirror::Schema.tiptap

  def markdown(*content, html: false, schema: self.schema) = schema.parse(doc(*content)).to_markdown(html:)

  def bold = {"type" => "bold"}

  def italic = {"type" => "italic"}

  def code = {"type" => "code"}

  def link(href, title = nil) = {"type" => "link", "attrs" => {"href" => href, "title" => title}.compact}

  def list(type, *items, attrs: nil)
    items = items.map { |item| {"type" => "list_item", "content" => item.is_a?(Array) ? item : [item]} }
    {"type" => type, "attrs" => attrs, "content" => items}.compact
  end

  def image(src, **attrs) = {"type" => "image", "attrs" => {"src" => src, **attrs.transform_keys(&:to_s)}}

  # What Markdown can't give back.
  ROUND_TRIP_DIFFERENCES = {
    "image_in_text" => "Markdown has no images outside paragraphs: the image comes back after an empty paragraph",
    "code_in_marks" => "spaces at the edges of bold move out of it"
  }.freeze

  # Importing the Markdown gives the document back.
  Dir[File.join(TestHelpers::FIXTURES, "markdown/*.json")].each do |path|
    next if ROUND_TRIP_DIFFERENCES.key?(File.basename(path, ".json"))

    fixture = JSON.parse(File.read(path))

    define_method(:"test_#{File.basename(path, ".json")}_round_trip") do
      schema = Prosemirror::Schema.tiptap(case: :camel)
      document = schema.parse(fixture["doc"])

      assert_equal document.to_h, schema.from_markdown(document.to_markdown).to_h
    end
  end

  def test_blocks
    assert_equal "# Title\n\nText\n\n> Quote\n\n---\n", markdown({"type" => "heading", "attrs" => {"level" => 1}, "content" => [text("Title")]},
      paragraph(text("Text")), {"type" => "blockquote", "content" => [paragraph(text("Quote"))]}, {"type" => "horizontal_rule"})
  end

  def test_escaping
    assert_equal "2 \\* 3 \\[a\\] \\`b\\` \\~c\\~ snake_case \\_\\_END\\_\\_\n", markdown(paragraph(text("2 * 3 [a] `b` ~c~ snake_case __END__")))
    assert_equal "\\# not a heading\n\n\\- not a list\n\n1\\. not a list\n", markdown(paragraph(text("# not a heading")), paragraph(text("- not a list")), paragraph(text("1. not a list")))
  end

  # Text that reads as HTML, or as a link, stays text.
  def test_escaping_html_and_autolinks
    assert_equal "\\<b> \\&amp; a < b\n", markdown(paragraph(text("<b> &amp; a < b")))
    assert_equal "https\\://a.fr www\\.b.fr a\\@c.fr\n", markdown(paragraph(text("https://a.fr www.b.fr a@c.fr")))
  end

  def test_marks
    assert_equal "**bold *both*** *it* ~~strike~~ `code`\n",
      markdown(paragraph(text("bold ", [bold]), text("both", [bold, italic]), text(" "), text("it", [italic]), text(" "),
        text("strike", [{"type" => "strike"}]), text(" "), text("code", [code])))
  end

  # Spaces inside emphasis move out of it, and emphasis CommonMark can't write here is dropped.
  def test_emphasis_spaces_and_punctuation
    assert_equal "a **b** c\n", markdown(paragraph(text("a"), text(" b ", [bold]), text("c")))
    assert_equal "Torra, ça (**gras**)\n", markdown(paragraph(text("Torra"), text(",", [bold]), text(" ça ("), text("gras", [bold]), text(")")))
    assert_equal "`id`**.**\n", markdown(paragraph(text("id", [code]), text(".", [bold])))
  end

  # Punctuation at an edge moves out of emphasis when that's enough to write it.
  def test_emphasis_with_punctuation_at_its_edges
    assert_equal "a«*b*»c\n", markdown(paragraph(text("a"), text("«b»", [italic]), text("c")))
    assert_equal "de l’*‘Association* et\n", markdown(paragraph(text("de l’"), text("‘Association", [italic]), text(" et")))
  end

  def test_links
    assert_equal "[a](/x \"T\") <https://b.fr> [c](/my%20url/%C3%A9\\(1\\))\n",
      markdown(paragraph(text("a", [link("/x", "T")]), text(" "), text("https://b.fr", [link("https://b.fr")]), text(" "), text("c", [link("/my url/é(1)")])))
  end

  # The longest mark opens first: bold around a link and the text after it doesn't close and reopen.
  def test_bold_around_a_link
    assert_equal "**[Nantes](/n) (C)**\n", markdown(paragraph(text("Nantes", [link("/n"), bold]), text(" (C)", [bold])))
  end

  def test_code
    assert_equal "`` a`b `` and ```` ``` ````\n", markdown(paragraph(text("a`b", [code]), text(" and "), text("```", [code])))
    assert_equal "````ruby\nputs \"```\"\n````\n", markdown({"type" => "code_block", "attrs" => {"language" => "ruby"}, "content" => [text("puts \"```\"")]})
  end

  def test_lists
    assert_equal "- a\n- b\n\n3. c\n4. d\n",
      markdown(list("bullet_list", paragraph(text("a")), paragraph(text("b"))), list("ordered_list", paragraph(text("c")), paragraph(text("d")), attrs: {"start" => 3}))
    assert_equal "- a\n\n  b\n\n- c\n", markdown(list("bullet_list", [paragraph(text("a")), paragraph(text("b"))], paragraph(text("c"))))
    assert_equal "- a\n  - b\n", markdown(list("bullet_list", [paragraph(text("a")), list("bullet_list", paragraph(text("b")))]))
  end

  # A list right after another of the same type switches markers, or Markdown would join them.
  def test_adjacent_lists
    assert_equal "- a\n\n* b\n\n- c\n\n1. d\n\n1) e\n",
      markdown(list("bullet_list", paragraph(text("a"))), list("bullet_list", paragraph(text("b"))), list("bullet_list", paragraph(text("c"))),
        list("ordered_list", paragraph(text("d"))), list("ordered_list", paragraph(text("e"))))
  end

  def test_hard_breaks
    assert_equal "a\\\nb\n", markdown(paragraph(text("a"), {"type" => "hard_break"}, text(" b"), {"type" => "hard_break"}))
  end

  def test_images
    assert_equal "![A \\*b\\*](/a.png \"T\") ![](/b.png)\n\ntext\n", markdown(image("/a.png", alt: "A *b*", title: "T"), image("/b.png"), paragraph(text("text")))
  end

  def test_empty_paragraphs_are_left_out
    assert_equal "a\n\nb\n", markdown(paragraph, paragraph(text("a")), paragraph, paragraph(text("b")))
  end

  def test_tables
    cell = ->(type, *content, align: nil) { {"type" => type, "attrs" => {"align" => align}.compact, "content" => content} }
    table = {"type" => "table", "content" => [
      {"type" => "table_row", "content" => [cell.call("table_header", paragraph(text("Left")), align: "left"), cell.call("table_header", paragraph(text("Right")), align: "right")]},
      {"type" => "table_row", "content" => [cell.call("table_cell", paragraph(text("a|b")), paragraph(text("c"))), cell.call("table_cell", list("bullet_list", paragraph(text("d"))))]}
    ]}

    assert_equal "| Left | Right |\n| :-- | --: |\n| a\\|b<br>c | <ul><li><p>d</p></li></ul> |\n", markdown(table)
  end

  def test_formatting_without_markdown_syntax
    content = [paragraph(text("u", [{"type" => "underline"}]), text("x", [{"type" => "highlight"}]), text("2", [{"type" => "superscript"}])),
      image("/a.png", width: 10)]

    assert_equal "ux2\n\n![](/a.png)\n", markdown(*content)
    assert_equal "<u>u</u><mark>x</mark><sup>2</sup>\n\n<img src=\"/a.png\" width=\"10\">\n", markdown(*content, html: true)
  end

  # Task lists and bullet lists in a row alternate markers, or Markdown would join them.
  def test_task_lists
    task = ->(checked, *content) { {"type" => "task_item", "attrs" => {"checked" => checked}, "content" => content} }

    assert_equal "- [x] done\n- [ ] todo\n  - [ ]\n\n* a\n\n- [ ] b\n",
      markdown({"type" => "task_list", "content" => [task.call(true, paragraph(text("done"))), task.call(false, paragraph(text("todo")),
        {"type" => "task_list", "content" => [task.call(false, paragraph)]})]}, list("bullet_list", paragraph(text("a"))),
        {"type" => "task_list", "content" => [task.call(false, paragraph(text("b")))]})
    assert_equal "- \\[x\\] text\n", markdown(list("bullet_list", paragraph(text("[x] text"))))
  end

  # As HTML, which GitHub reads, with Markdown content. Markdown import reads it back with the herb gem.
  def test_details
    schema = Prosemirror::Schema.tiptap(case: :camel)
    details = {"type" => "details", "content" => [{"type" => "detailsSummary", "content" => [text("a < "), text("b", [bold])]},
      {"type" => "detailsContent", "content" => [paragraph(text("c", [italic])), list("bulletList", paragraph(text("d")))]}]}
    document = schema.parse(doc({"type" => "blockquote", "content" => [details]}))

    assert_equal "> <details>\n> <summary>a &lt; <strong>b</strong></summary>\n>\n> *c*\n>\n> - d\n>\n> </details>\n", document.to_markdown
    assert_equal document.to_h, schema.from_markdown(document.to_markdown).to_h
  end

  # A mention is its text, or with `html: true`, HTML that Markdown import reads back.
  def test_mentions
    schema = Prosemirror::Schema.tiptap(case: :camel)
    document = schema.parse(doc(paragraph(text("Hi "), {"type" => "mention", "attrs" => {"id" => "1", "label" => "Ada *", "mentionSuggestionChar" => "@"}},
      {"type" => "mention", "attrs" => {"id" => "release", "label" => nil, "mentionSuggestionChar" => "#"}, "marks" => [bold]})))

    assert_equal "Hi @Ada \\***#release**\n", document.to_markdown
    assert_equal document.to_h, schema.from_markdown(document.to_markdown(html: true)).to_h
  end

  def test_prosemirror_schema
    schema = Prosemirror::Schema.prosemirror

    assert_equal "**a** *b* `c` ![i](/i.png)\n\n```\nx\n```\n\n2. d\n",
      markdown(paragraph(text("a", [{"type" => "strong"}]), text(" "), text("b", [{"type" => "em"}]), text(" "), text("c", [code]), text(" "), image("/i.png", alt: "i")),
        {"type" => "code_block", "content" => [text("x")]}, list("ordered_list", paragraph(text("d")), attrs: {"order" => 2}), schema:)
  end

  def test_custom_types
    callout = Class.new(Prosemirror::NodeType) do
      type_name :callout
      group :block
      content "paragraph+"

      def to_markdown(markdown, _parent, _index)
        markdown.wrap_block("> ", "> **Note:** ", node) { markdown.render_content(node) }
      end
    end
    keyboard = Class.new(Prosemirror::MarkType) do
      type_name :kbd
      markdown open: "<kbd>", close: "</kbd>", escape: false
    end
    schema = Prosemirror::Schema.tiptap.with(callout, keyboard)

    assert_equal "> **Note:** Press <kbd>Ctrl</kbd>\n",
      markdown({"type" => "callout", "content" => [paragraph(text("Press "), text("Ctrl", [{"type" => "kbd"}]))]}, schema:)
  end

  # Without `to_markdown`, a type writes its content.
  def test_types_without_markdown
    aside = Class.new(Prosemirror::NodeType) do
      type_name :aside
      group :block
      content "paragraph+"
    end

    assert_equal "a\n\nb\n", markdown({"type" => "aside", "content" => [paragraph(text("a")), paragraph(text("b"))]}, schema: schema.with(aside))
  end
end
