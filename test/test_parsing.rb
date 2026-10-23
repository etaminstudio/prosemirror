# frozen_string_literal: true

require "test_helper"

class TestParsing < Minitest::Test
  include TestHelpers

  def test_parses_json_strings_and_symbol_keys
    string = Prosemirror.parse('{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"x"}]}]}')
    symbols = Prosemirror.parse({ type: "doc",
                                  content: [{ type: "paragraph", content: [{ type: "text", text: "x" }] }] })

    assert_equal string, symbols
    assert_equal "<p>x</p>", symbols.to_html
  end

  def test_optional_attributes_can_be_missing
    json = doc({ "type" => "image", "attrs" => { "src" => "/a.png" } })

    assert_equal '<img src="/a.png">', render(json)
    assert_empty problems(json)
  end

  def test_rejects_other_inputs
    assert_raises(ArgumentError) { Prosemirror.parse([]) }
  end

  def test_accepts_snake_case_and_camel_case_types
    snake = Prosemirror.parse(doc({ "type" => "horizontal_rule" }))
    camel = Prosemirror.parse(doc({ "type" => "horizontalRule" }))

    assert_equal snake, camel
    assert_equal :horizontal_rule, camel.content.first.type
  end

  def test_accepts_prosemirror_names
    json = doc(paragraph(text("x", [{ "type" => "strong" }, { "type" => "em" }])),
               { "type" => "ordered_list", "attrs" => { "order" => 3 },
                 "content" => [{ "type" => "list_item", "content" => [paragraph(text("y"))] }] },
               { "type" => "code_block", "attrs" => { "params" => "ruby" }, "content" => [text("z")] })

    assert_equal '<p><strong><em>x</em></strong></p><ol start="3"><li><p>y</p></li></ol>' \
                 '<pre><code class="language-ruby">z</code></pre>', render(json)
  end

  def test_outputs_snake_case_by_default
    json = Prosemirror.parse(doc({ "type" => "hardBreak" })).to_h

    assert_equal({ "type" => "doc", "content" => [{ "type" => "hard_break" }] }, json)
  end

  def test_outputs_camel_case_type_names
    schema = Prosemirror::Schema.tiptap(case: :camel)
    json = Prosemirror.parse(doc({ "type" => "hard_break" }), schema: schema).to_h

    assert_equal({ "type" => "doc", "content" => [{ "type" => "hardBreak" }] }, json)
  end

  def test_case_does_not_change_attribute_names
    schema = Prosemirror::Schema.tiptap(case: :camel)
    mark = { "type" => "link", "attrs" => { "href" => "https://example.com", "class" => "external" } }
    json = Prosemirror.parse(doc(paragraph(text("x", [mark]))), schema: schema).to_h

    assert_equal({ "href" => "https://example.com", "target" => nil, "rel" => nil, "class" => "external",
                   "title" => nil },
                 json.dig("content", 0, "content", 0, "marks", 0, "attrs"))
  end

  def test_to_h_includes_all_attributes_with_their_defaults
    json = Prosemirror.parse(doc({ "type" => "heading", "content" => [text("x")] })).to_h

    assert_equal({ "level" => 1 }, json.dig("content", 0, "attrs"))
  end

  def test_to_json
    document = Prosemirror.parse(doc(paragraph(text("x"))))

    assert_equal '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"x"}]}]}',
                 document.to_json
  end

  def test_joins_adjacent_text_with_the_same_marks
    json = doc(paragraph(text("a", [{ "type" => "bold" }]), text("b", [{ "type" => "bold" }]), text("c")))
    paragraph = Prosemirror.parse(json).content.first

    assert_equal(%w[ab c], paragraph.content.map(&:text))
  end

  def test_removes_empty_text
    json = doc(paragraph(text(""), text("a")))

    assert_equal ["a"], Prosemirror.parse(json).content.first.content.map(&:text)
  end

  def test_sorts_marks_in_schema_order_and_removes_duplicates
    marks = [{ "type" => "italic" }, { "type" => "link", "attrs" => { "href" => "/" } }, { "type" => "italic" }]
    node = Prosemirror.parse(doc(paragraph(text("x", marks)))).content.first.first_child

    assert_equal %i[link italic], node.marks.map(&:type)
  end

  def test_wraps_a_root_that_is_not_a_doc
    reported = problems(paragraph(text("x")))

    assert_equal "<p>x</p>", render(paragraph(text("x")))
    assert_equal ["doc: the top node is paragraph, not doc"], reported
  end

  def test_converts_attributes_when_the_meaning_is_clear
    json = doc({ "type" => "heading", "attrs" => { "level" => "2" }, "content" => [text("x")] })

    assert_equal "<h2>x</h2>", render(json)
    assert_empty problems(json)
  end

  def test_uses_the_default_for_invalid_attributes
    json = doc({ "type" => "heading", "attrs" => { "level" => "abc" }, "content" => [text("x")] })

    assert_equal "<h1>x</h1>", render(json)
    assert_equal ['doc.content[0]: invalid attribute level: "abc"'], problems(json)
  end

  def test_removes_nodes_missing_a_required_attribute
    json = doc({ "type" => "image", "attrs" => { "alt" => "x" } }, paragraph(text("after")))

    assert_equal "<p>after</p>", render(json)
    assert_equal ["doc.content[0]: missing attribute src", "doc.content[0]: removed image node"], problems(json)
  end

  def test_removes_marks_missing_a_required_attribute_and_keeps_the_text
    json = doc(paragraph(text("x", [{ "type" => "link" }])))

    assert_equal "<p>x</p>", render(json)
  end

  def test_keeps_unknown_nodes_and_marks
    json = doc({ "type" => "callout", "attrs" => { "tone" => "info" },
                 "content" => [paragraph(text("x", [{ "type" => "glow" }]))] })
    document = Prosemirror.parse(json, schema: Prosemirror::Schema.tiptap(on_invalid: ->(_) {}))

    assert_equal "<p>x</p>", document.to_html
    assert_equal json, document.to_h
  end

  def test_reports_unknown_types
    json = doc({ "type" => "callout", "content" => [paragraph(text("x", [{ "type" => "glow" }]))] })

    assert_equal ["doc.content[0]: unknown node type callout",
                  "doc.content[0].content[0].content[0].marks[0]: unknown mark type glow"], problems(json)
  end

  def test_strict_mode_raises
    schema = Prosemirror::Schema.tiptap(strict: true)
    json = doc({ "type" => "heading", "attrs" => { "level" => "abc" } })

    error = assert_raises(Prosemirror::InvalidDocument) { Prosemirror.parse(json, schema: schema) }
    assert_equal "doc.content[0]", error.path
  end

  def test_strict_mode_raises_on_forbidden_urls_when_rendering
    schema = Prosemirror::Schema.tiptap(strict: true)
    document = Prosemirror.parse(doc(paragraph(text("x", [{ "type" => "link",
                                                            "attrs" => { "href" => "javascript:x" } }]))),
                                 schema: schema)

    assert_raises(Prosemirror::InvalidDocument) { document.to_html }
  end

  def test_ignores_malformed_parts
    json = { "type" => "doc", "content" => [nil, "x", { "content" => [] }, paragraph({ "type" => "text" })] }

    assert_equal "<p></p>", render(json)
  end
end
