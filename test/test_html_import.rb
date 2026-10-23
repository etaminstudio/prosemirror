# frozen_string_literal: true

require "test_helper"

class TestHTMLImport < Minitest::Test
  include TestHelpers

  def schema = Prosemirror::Schema.tiptap(case: :camel)

  def import(html, schema: self.schema) = Prosemirror.from_html(html, schema:).to_h

  # Each fixture holds HTML, and the JSON Tiptap's `generateJSON` gives for it, with StarterKit, Image,
  # TableKit, Subscript, Superscript and Highlight (with colors), and links without default attributes.
  Dir[File.join(TestHelpers::FIXTURES, "html/*.json")].each do |path|
    fixture = JSON.parse(File.read(path))

    define_method(:"test_#{File.basename(path, ".json")}_like_tiptap") do
      assert_equal fixture["doc"], import(fixture["html"])
    end
  end

  # Tiptap keeps `"color": ""` for a highlight without a color.
  def test_highlight_without_a_color
    marks = import("<p><mark>m</mark></p>").dig("content", 0, "content", 0, "marks")

    assert_equal [{"type" => "highlight", "attrs" => {"color" => nil}}], marks
  end

  # Tiptap keeps `"50%"`: HTML's `width` and `height` only take integers.
  def test_image_dimensions_are_integers
    attrs = import(%(<img src="/a.png" width="100" height="50%">), schema: schema.with_options(on_invalid: ->(_) {}))
      .dig("content", 0, "attrs")

    assert_equal({"src" => "/a.png", "alt" => nil, "title" => nil, "width" => 100, "height" => nil}, attrs)
  end

  def test_old_html
    assert_equal doc(paragraph(text("font"), text("center"), text("tt", [{"type" => "code"}]))).then { |json| schema.parse(json).to_h },
      import(%(<font color="red">font</font><center>center</center><tt>tt</tt>))
  end

  def test_erb_is_kept_as_text
    assert_equal "Price <%= price %>", Prosemirror.from_html("<p>Price <%= price %></p>").text_content
  end

  def test_unclosed_elements_apply_to_the_rest_of_their_parent
    marks = import("<p>a <strong>b</p><p>c</p>").dig("content", 0, "content", 1, "marks")

    assert_equal [{"type" => "bold"}], marks
    assert_equal({"type" => "paragraph", "content" => [{"type" => "text", "text" => "c"}]}, import("<p>a <strong>b</p><p>c</p>").dig("content", 1))
  end

  def test_deep_nesting_is_flattened
    document = Prosemirror.from_html(("<div>" * 1000) + "deep")

    assert_equal "deep", document.text_content
  end

  # Herb stops after a second by default, and returns what it parsed so far: an 11 MB document came out empty.
  def test_herb_has_no_time_limit
    Prosemirror::HTML::Builder.load_herb
    parse = Herb.method(:parse)
    timeouts = []
    Herb.stub(:parse, ->(html, **options) { timeouts << options[:timeout] && parse.call(html, **options) }) do
      Prosemirror.from_html("<p>x</p>")
    end

    assert_equal [0], timeouts
  end

  def test_prosemirror_schema
    document = Prosemirror.from_html(%(<ol start="3"><li><b>x</b> <code><i>y</i></code></li></ol><p>a <img src="/i.png" alt="i"> b</p>),
      schema: Prosemirror::Schema.prosemirror)

    assert_equal({"type" => "doc", "content" => [
      {"type" => "ordered_list", "attrs" => {"order" => 3}, "content" => [{"type" => "list_item", "content" => [
        {"type" => "paragraph", "content" => [
          {"type" => "text", "text" => "x", "marks" => [{"type" => "strong"}]},
          {"type" => "text", "text" => " "},
          {"type" => "text", "text" => "y", "marks" => [{"type" => "em"}, {"type" => "code"}]}
        ]}
      ]}]},
      {"type" => "paragraph", "content" => [
        {"type" => "text", "text" => "a "},
        {"type" => "image", "attrs" => {"src" => "/i.png", "alt" => "i", "title" => nil}},
        {"type" => "text", "text" => " b"}
      ]}
    ]}, document.to_h)
  end

  def test_custom_parse_rules
    callout = Class.new(Prosemirror::NodeType) do
      type_name :callout
      group :block
      content "inline*"
      prop :tone, _String?, parse_html: ->(element) { element["data-tone"] }

      parse_html tag: "aside.callout"
      parse_html(tag: "div") { |element| element.classes.include?("note") && {tone: "note"} }
    end
    json = Prosemirror.from_html(%(<aside class="callout" data-tone="warn">a</aside><div class="note">b</div><div>c</div>),
      schema: Prosemirror::Schema.tiptap.with(callout)).to_h

    assert_equal [["callout", {"tone" => "warn"}], ["callout", {"tone" => "note"}], ["paragraph", nil]],
      json["content"].map { |node| [node["type"], node["attrs"]] }
  end

  def test_needs_herb
    assert_raises(Prosemirror::Error) do
      Prosemirror::HTML::Builder.stub(:load_herb, -> { raise Prosemirror::Error, "needs herb" }) { Prosemirror.from_html("<p>x</p>") }
    end
  end
end
