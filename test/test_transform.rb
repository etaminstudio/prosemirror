# frozen_string_literal: true

require "test_helper"

class TestTransform < Minitest::Test
  include TestHelpers

  def bullet_list(*items) = {"type" => "bullet_list", "content" => items}

  def list_item(*content) = {"type" => "list_item", "content" => content}

  def heading(level, *content) = {"type" => "heading", "attrs" => {"level" => level}, "content" => content}

  def parse(*content, **) = Prosemirror::Schema.tiptap(**).parse(doc(*content))

  def test_returns_a_new_document
    document = parse(paragraph(text("a")))
    same = document.transform { |node| node }

    assert_equal document, same
    refute_same document, same
  end

  def test_replace_remove_and_splice
    document = parse(heading(1, text("Title")), paragraph, bullet_list(list_item(paragraph(text("a"))), list_item(paragraph(text("b")))))

    transformed = document.transform do |node|
      case node
      in {type: :heading} then node.with(attrs: {level: 2})
      in {type: :paragraph} if node.blank? then nil
      in {type: :bullet_list} then node.content.flat_map(&:content)
      else node
      end
    end

    assert_equal doc(heading(2, text("Title")), paragraph(text("a")), paragraph(text("b"))), transformed.to_h
  end

  # Children are transformed first: the block sees the list with its new items, and nodes it returns aren't
  # transformed again.
  def test_children_first
    seen = []
    parse(bullet_list(list_item(paragraph(text("a"))))).transform do |node|
      seen << node.type
      (node.type == :text) ? node.with(text: "b") : node
    end

    assert_equal %i[text paragraph list_item bullet_list], seen
  end

  def test_rewrite_link_marks_and_join_text
    link = ->(href) { {"type" => "link", "attrs" => {"href" => href}} }
    document = parse(paragraph(text("a", [link.call("/old")]), text("b", [link.call("/other")])))

    transformed = document.transform do |node|
      next node unless node.text?

      node.with(marks: node.marks.map { |mark| (mark.type == :link) ? mark.with(attrs: mark.attrs.merge(href: "/new")) : mark })
    end

    assert_equal [{"type" => "text", "text" => "ab", "marks" => [{"type" => "link", "attrs" => {"href" => "/new", "target" => nil, "rel" => nil, "class" => nil, "title" => nil}}]}],
      transformed.to_h.dig("content", 0, "content")
  end

  def test_empty_text_is_removed
    transformed = parse(paragraph(text("a"), text("b", [{"type" => "bold"}]))).transform { |node| (node.text == "a") ? node.with(text: "") : node }

    assert_equal [text("b", [{"type" => "bold"}])], transformed.to_h.dig("content", 0, "content")
  end

  def test_required_content_is_added_and_reported
    reported = []
    document = parse(bullet_list(list_item(paragraph)), on_invalid: ->(error) { reported << error.message })

    transformed = document.transform { |node| (node.type == :paragraph) ? nil : node }

    assert_equal doc(bullet_list(list_item({"type" => "paragraph"}))), transformed.to_h
    assert_equal ["doc.content[0].content[0]: added required paragraph to list_item"], reported
  end

  # The block sees the emptied list item, and nothing is added when it removes it.
  def test_removed_nodes_are_not_filled
    reported = []
    document = parse(paragraph(text("a")), bullet_list(list_item(paragraph)), on_invalid: ->(error) { reported << error.message })

    transformed = document.transform do |node|
      case node
      in {type: :paragraph | :list_item} if node.blank? then nil
      in {type: :bullet_list} if node.content.empty? then nil
      else node
      end
    end

    assert_equal doc(paragraph(text("a"))), transformed.to_h
    assert_empty reported
  end

  def test_required_content_is_added_after_or_left_to_check
    caption = Class.new(Prosemirror::NodeType) do
      type_name :caption
      content "text*"
    end
    figure = Class.new(Prosemirror::NodeType) do
      type_name :figure
      group :block
      content "paragraph caption"
    end
    schema = Prosemirror::Schema.tiptap(on_invalid: ->(_) {}).with(figure, caption)
    document = schema.parse(doc({"type" => "figure", "content" => [paragraph(text("a")), {"type" => "caption", "content" => [text("c")]}]}))

    without_caption = document.transform { |node| (node.type == :caption) ? nil : node }
    assert_equal [{"type" => "paragraph", "content" => [text("a")]}, {"type" => "caption"}], without_caption.to_h.dig("content", 0, "content")

    # A heading can't go in a figure: the content is left as it is, for `check` to report.
    with_heading = document.transform { |node| (node.type == :caption) ? Prosemirror::Node.new(type: :heading, attrs: {level: 1}) : node }
    assert_equal %w[paragraph heading], with_heading.to_h.dig("content", 0, "content").map { |node| node["type"] }
    refute with_heading.valid?
  end

  def test_an_emptied_document_gets_a_paragraph
    assert_equal doc({"type" => "paragraph"}), parse(paragraph(text("a"))).transform { nil }.to_h
  end

  def test_strict_mode_raises_instead_of_adding
    document = parse(bullet_list(list_item(paragraph)), strict: true)

    assert_raises(Prosemirror::InvalidDocument) { document.transform { |node| (node.type == :paragraph) ? nil : node } }
  end

  def test_unknown_attributes_are_kept
    document = Prosemirror::Schema.tiptap(case: :camel).parse(doc({"type" => "paragraph", "attrs" => {"textAlign" => "center"}, "content" => [text("a")]}))

    assert_equal({"textAlign" => "center"}, document.transform { |node| node }.to_h.dig("content", 0, "attrs"))
  end

  def test_the_block_must_return_nodes
    error = assert_raises(ArgumentError) { parse(paragraph(text("a"))).transform { "x" } }

    assert_match(/returns a node, an array of nodes or nil/, error.message)
    assert_raises(ArgumentError) { parse(paragraph(text("a"))).transform }
  end

  def test_blank
    schema = Prosemirror::Schema.tiptap
    blank = ->(json) { schema.parse(doc(json)).content.first.blank?(schema) }

    assert blank.call(paragraph)
    assert blank.call(paragraph(text("  \n"), {"type" => "hard_break"}))
    assert blank.call(bullet_list(list_item(paragraph)))
    refute blank.call(paragraph(text("a")))
    refute blank.call({"type" => "image", "attrs" => {"src" => "/a.png"}})
    refute blank.call({"type" => "horizontal_rule"})
  end
end
