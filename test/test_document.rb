# frozen_string_literal: true

require "test_helper"

class TestDocument < Minitest::Test
  include TestHelpers

  def document
    Prosemirror.parse(doc({ "type" => "heading", "attrs" => { "level" => 1 }, "content" => [text("Title")] },
                          paragraph(text("Hello "), text("World", [{ "type" => "bold" }])),
                          { "type" => "image", "attrs" => { "src" => "/a.png" } }))
  end

  def test_enumerates_all_nodes
    assert_equal %i[heading text paragraph text text image], document.map(&:type)
  end

  def test_pattern_matching
    headings = document.select { |node| node in { type: :heading, attrs: { level: 1 } } }

    assert_equal ["Title"], headings.map(&:text_content)
  end

  def test_marks_support_pattern_matching
    bold = document.find { |node| node.marks.any? { |mark| mark in { type: :bold } } }

    assert_equal "World", bold.text
  end

  def test_text_content
    assert_equal "TitleHello World", document.text_content
  end

  def test_to_text_with_a_block_separator
    assert_equal "Title\nHello World", document.to_text(block_separator: "\n")
  end

  def test_nodes_are_frozen
    node = document.content.first

    assert_predicate node, :frozen?
    assert_predicate node.attrs, :frozen?
    assert_predicate node.content, :frozen?
  end

  def test_node_helpers
    paragraph = document.content[1]

    assert_equal "Hello ", paragraph.first_child.text
    assert_equal "World", paragraph.last_child.text
    assert_equal 2, paragraph.child_count
    assert paragraph.first_child.text?
    assert paragraph.same_markup?(paragraph.with(content: []))
  end

  def test_html_safe_with_active_support
    html = document.to_html

    refute_respond_to html, :html_safe? unless defined?(ActiveSupport)
    assert_kind_of String, html
  end
end
