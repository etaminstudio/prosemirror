# frozen_string_literal: true

require "test_helper"

class TestMarkdownImport < Minitest::Test
  def schema = Prosemirror::Schema.tiptap(case: :camel)

  def import(markdown, schema: self.schema) = Prosemirror.from_markdown(markdown, schema:).to_h

  def content(markdown, **) = import(markdown, **)["content"]

  # Each fixture holds Markdown, and the JSON Tiptap's `generateJSON` gives for the HTML commonmarker renders
  # for it, with the HTML import fixtures' extensions. Code blocks lose their final newline, as in
  # prosemirror-markdown.
  Dir[File.join(TestHelpers::FIXTURES, "markdown/*.json")].each do |path|
    fixture = JSON.parse(File.read(path))

    define_method(:"test_#{File.basename(path, ".json")}_like_tiptap") do
      assert_equal fixture["doc"], import(fixture["markdown"])
    end
  end

  def task_item(checked, *content) = {"type" => "taskItem", "attrs" => {"checked" => checked}, "content" => content}

  def paragraph(*texts) = {"type" => "paragraph", "content" => texts.map { |text| text.is_a?(String) ? {"type" => "text", "text" => text} : text }}.reject { |_, value| value == [] }

  # commonmarker doesn't say whether an item is checked: it's read from the Markdown, in any container.
  def test_task_lists
    assert_equal [{"type" => "taskList", "content" => [task_item(false, paragraph("todo")),
      task_item(true, paragraph("done"), {"type" => "taskList", "content" => [task_item(true, paragraph("nested"), paragraph("more"))]}),
      task_item(false, paragraph)]}], content("- [ ] todo\n- [X] done\n  - [x] nested\n\n    more\n- [ ]\n")
    assert_equal [{"type" => "blockquote", "content" => [{"type" => "taskList", "content" => [task_item(true, paragraph("quoted"))]}]}],
      content("> * [x] quoted\n")
  end

  # In a bullet list with other items, and in ordered lists, which Tiptap's task lists aren't, checkboxes stay
  # as text.
  def test_checkboxes_outside_task_lists
    list = ->(type, *items) { {"type" => type, "content" => items.map { |item| {"type" => "listItem", "content" => [item]} }} }

    assert_equal [list.call("bulletList", paragraph("plain"), paragraph("[x] ", {"type" => "text", "text" => "done", "marks" => [{"type" => "italic"}]}), paragraph("[ ]")),
      list.call("orderedList", paragraph("[ ] ordered")).merge("attrs" => {"start" => 1, "type" => nil})],
      content("- plain\n- [x] *done*\n- [ ]\n\n1. [ ] ordered\n")
  end

  # Neither GitHub nor Tiptap has other states, like `[~]`.
  def test_other_checkboxes_are_text
    assert_equal "[~] dropped", content("- [~] dropped\n").dig(0, "content", 0, "content", 0, "content", 0, "text")
  end

  # With raw HTML, the document goes through HTML import, which reads GitHub's task lists.
  def test_task_lists_with_raw_html
    assert_equal [{"type" => "taskList", "content" => [task_item(false, paragraph("a ", {"type" => "text", "text" => "b", "marks" => [{"type" => "bold"}]})),
      task_item(true, paragraph("c"))]}], content("- [ ] a <b>b</b>\n- [x] c\n")
  end

  def test_raw_html_stays_as_text_without_herb
    Prosemirror::HTML::Builder.stub(:herb?, false) do
      assert_equal [{"type" => "paragraph", "content" => [{"type" => "text", "text" => "a <b>b</b>"}]},
        {"type" => "paragraph", "content" => [{"type" => "text", "text" => "<div>c</div>"}]}],
        content("a <b>b</b>\n\n<div>c</div>\n")
    end
  end

  # Raw HTML can span Markdown blocks: the whole document goes through HTML import.
  def test_raw_html_around_markdown
    assert_equal [{"type" => "paragraph", "content" => [{"type" => "text", "text" => "foo", "marks" => [{"type" => "italic"}, {"type" => "strike"}]}]}],
      content("<del>\n\n*foo*\n\n</del>\n")
  end

  def test_code_blocks_lose_their_final_newline_with_raw_html_too
    # A `<pre>` written in HTML keeps its newlines, as in HTML import.
    assert_equal ["x", "code", "\nraw\n"],
      content("<b>x</b>\n\n```\ncode\n```\n\n<pre>\nraw\n</pre>\n").map { |node| node.dig("content", 0, "text") }
  end

  def test_urls_are_percent_encoded_as_commonmarker_renders_them
    link = ->(markdown) { content(markdown).dig(0, "content", 0, "marks", 0, "attrs", "href") }

    assert_equal "/my%20url", link.call("[a](</my url>)")
    assert_equal "/f%C3%B6%C3%B6?a=1&b='2'", link.call("[a](/f&ouml;&ouml;?a=1&b='2')")
    assert_equal "/already%20encoded%252", link.call("[a](/already%20encoded%2)")
    assert_equal "http://[::1]:80/%5Bx%5D", link.call("<http://[::1]:80/[x]>")
  end

  def test_table_alignment_in_a_blockquote
    cells = content("> | a | b | c |\n> |:-:|--:|---|\n> | 1 | 2 | 3 |\n").dig(0, "content", 0, "content", 1, "content")

    assert_equal ["center", "right", nil], cells.map { |cell| cell.dig("attrs", "align") }
  end

  def test_custom_types_use_their_parse_rules
    image_block = Class.new(Prosemirror::NodeType) do
      type_name :image_block
      group :block
      prop :src, String
      parse_html tag: "img", priority: 60
    end

    assert_equal [{"type" => "paragraph", "content" => [{"type" => "text", "text" => "Before"}]},
      {"type" => "imageBlock", "attrs" => {"src" => "/a.png"}},
      {"type" => "paragraph", "content" => [{"type" => "text", "text" => " after"}]}],
      content("Before ![a](/a.png) after\n", schema: schema.with(image_block))
  end

  def test_prosemirror_schema
    assert_equal [{"type" => "paragraph", "content" => [
      {"type" => "text", "text" => "a", "marks" => [{"type" => "strong"}]},
      {"type" => "text", "text" => " "},
      {"type" => "image", "attrs" => {"src" => "/i.png", "alt" => "i", "title" => nil}},
      {"type" => "text", "text" => " gone"}
    ]}], content("**a** ![i](/i.png) ~~gone~~", schema: Prosemirror::Schema.prosemirror)
  end

  def test_deep_nesting_is_flattened
    assert_equal "deep", Prosemirror.from_markdown(("> " * 300) + "deep").text_content
  end

  # Nodes nested deeper than JSON documents can be are flattened, so that the document can be saved and parsed again.
  def test_deep_nodes_are_flattened
    document = Prosemirror.from_markdown(("> " * 300) + "deep")

    assert_equal document, Prosemirror.parse(document.to_json)
  end

  def test_front_matter_is_dropped
    assert_equal [{"type" => "heading", "attrs" => {"level" => 1}, "content" => [{"type" => "text", "text" => "Body"}]}],
      content("---\ntitle: Hello\ntags: [a]\n---\n\n# Body\n")
  end

  def test_nil_and_binary_strings
    assert_equal [{"type" => "paragraph"}], content(nil)
    assert_equal "café", Prosemirror.from_markdown("café".b).text_content
  end

  def test_invalid_utf8_is_replaced
    assert_equal "caf\uFFFD x", Prosemirror.from_markdown("caf\xE9 *x*".dup.force_encoding("UTF-8")).text_content
  end

  def test_too_deep_nesting_raises
    error = assert_raises(Prosemirror::TooDeep) { Prosemirror.from_markdown(("*a " * 2000) + "x" + (" a*" * 2000)) }

    assert_match(/nested too deeply/, error.message)
  end

  def test_needs_commonmarker
    Prosemirror::Markdown::Builder.stub(:load_commonmarker, -> { raise Prosemirror::Error, "needs commonmarker" }) do
      assert_raises(Prosemirror::Error) { Prosemirror.from_markdown("x") }
    end
  end
end
