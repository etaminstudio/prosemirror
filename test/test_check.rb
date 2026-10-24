# frozen_string_literal: true

require "test_helper"

class TestCheck < Minitest::Test
  include TestHelpers

  def parse(json, schema: Prosemirror::Schema.tiptap(on_invalid: ->(_) {})) = schema.parse(json)

  def problem(document)
    document.check
    nil
  rescue Prosemirror::InvalidDocument => error
    error.message
  end

  def test_valid_documents
    document = parse(doc(paragraph(text("a", [{"type" => "bold"}])), {"type" => "bullet_list", "content" => [{"type" => "list_item", "content" => [paragraph(text("b"))]}]}))

    assert_same document, document.check
    assert document.valid?
  end

  def test_content_expressions
    assert_equal "doc: invalid content for doc: nothing", problem(parse({"type" => "doc"}))
    assert_equal "doc.content[0]: invalid content for blockquote: paragraph text",
      problem(parse(doc({"type" => "blockquote", "content" => [paragraph(text("a")), text("b")]})))
    refute parse({"type" => "doc"}).valid?
  end

  def test_unknown_types
    assert_equal "doc.content[0]: unknown node type callout", problem(parse(doc({"type" => "callout", "content" => [paragraph(text("a"))]})))
    assert_equal "doc.content[0].content[0].marks[0]: unknown mark type sparkle",
      problem(parse(doc(paragraph(text("a", [{"type" => "sparkle"}])))))
  end

  def test_attributes
    document = parse(doc({"type" => "heading", "attrs" => {"level" => 1}, "content" => [text("a")]}))
      .transform { |node| (node.type == :heading) ? node.with(attrs: {level: 9}) : node }

    assert_equal "doc.content[0]: invalid attribute level: 9", problem(document)
  end

  def test_marks_the_parent_doesnt_allow
    document = parse(doc({"type" => "code_block", "content" => [text("x")]}))
      .transform { |node| node.text? ? node.with(marks: [Prosemirror::Mark.new(type: :bold)]) : node }

    assert_equal "doc.content[0].content[0]: code_block doesn't allow bold marks", problem(document)
  end

  def test_marks_out_of_order_or_excluded
    reorder = ->(marks) { parse(doc(paragraph(text("a")))).transform { |node| node.text? ? node.with(marks: marks) : node } }

    assert_equal "doc.content[0].content[0]: invalid marks: italic bold",
      problem(reorder.call([Prosemirror::Mark.new(type: :italic), Prosemirror::Mark.new(type: :bold)]))
    assert_equal "doc.content[0].content[0]: invalid marks: bold code",
      problem(reorder.call([Prosemirror::Mark.new(type: :bold), Prosemirror::Mark.new(type: :code)]))
  end

  def test_leaves_and_text
    with_content = parse(doc(paragraph(text("a")))).transform do |node|
      (node.type == :paragraph) ? [node, Prosemirror::Node.new(type: :horizontal_rule, content: [Prosemirror::Node.new(type: :text, text: "x")])] : node
    end

    assert_equal "doc.content[1]: horizontal_rule has no content, but has 1 nodes", problem(with_content)
  end

  # A link's `class` is the `css_class` property: its JSON name differs from its property name.
  def test_attributes_with_a_json_name
    document = parse(doc(paragraph(text("a", [{"type" => "link", "attrs" => {"href" => "/a", "class" => "external"}}]))))

    assert document.valid?, problem(document)
  end

  def test_camel_case_names
    schema = Prosemirror::Schema.tiptap(case: :camel, on_invalid: ->(_) {})

    assert_equal "doc.content[0]: unknown node type imageBlock", problem(parse(doc({"type" => "imageBlock"}), schema:))
  end
end
