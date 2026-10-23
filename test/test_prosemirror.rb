# frozen_string_literal: true

require "test_helper"

class TestProsemirror < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Prosemirror::VERSION
  end

  def test_default_schema_is_tiptap
    assert_equal Prosemirror::Schema.tiptap.nodes, Prosemirror.schema.nodes
  end

  def test_schemas_are_frozen
    assert_predicate Prosemirror::Schema.tiptap, :frozen?
  end

  def test_schema_options_are_type_checked
    assert_raises(Literal::TypeError) { Prosemirror::Schema.tiptap(case: :kebab) }
    assert_raises(Literal::TypeError) { Prosemirror::Schema.tiptap(on_invalid: "log") }
    assert_raises(Literal::TypeError) { Prosemirror::Schema.tiptap(strict: "yes") }
    assert_raises(Literal::TypeError) { Prosemirror::Schema.new(nodes: [String], marks: []) }
  end

  def test_schema_needs_its_top_node
    assert_raises(ArgumentError) { Prosemirror::Schema.new(nodes: [Prosemirror::Nodes::Paragraph], marks: []) }
  end

  def test_with_options
    schema = Prosemirror::Schema.tiptap.with_options(strict: true)

    assert_predicate schema, :strict?
    assert_equal Prosemirror::Schema.tiptap.nodes, schema.nodes
  end

  def test_nodes_are_type_checked
    assert_raises(Literal::TypeError) { Prosemirror::Node.new(type: :paragraph, content: ["text"]) }
    assert_raises(Literal::TypeError) { Prosemirror::Node.new(type: :text, text: 42) }
  end

  def test_node_with
    node = Prosemirror::Node.new(type: "text", text: "a")

    assert_equal "b", node.with(text: "b").text
    assert_equal :text, node.type
  end
end
