# frozen_string_literal: true

require "test_helper"

# The recipes from COOKBOOK.md.
class TestCookbook < Minitest::Test
  include TestHelpers

  class SkipEmptyParagraphs < Prosemirror::Nodes::Paragraph
    def view_template(&)
      p(&) unless node.content.empty?
    end
  end

  class SkipBlankParagraphs < Prosemirror::Nodes::Paragraph
    def view_template(&)
      p(&) unless node.blank?(prosemirror_schema)
    end
  end

  class Heading < Prosemirror::Nodes::Heading
    prop :id, _String?

    def view_template(&)
      tag(:"h#{@level}", id: @id || slug, &)
    end

    private

    def slug
      slug = node.text_content.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").downcase.gsub(/[^a-z0-9]+/, "-")
      slug = slug.delete_prefix("-").delete_suffix("-")
      slug unless slug.empty?
    end
  end

  class Figure < Phlex::HTML
    def initialize(src:, caption:)
      @src = src
      @caption = caption
    end

    def view_template
      figure do
        img(src: @src)
        figcaption { @caption } if @caption
      end
    end
  end

  class ImageBlock < Prosemirror::NodeType
    group :block

    prop :src, String
    prop :caption, _String?

    def view_template
      render Figure.new(src: safe_url(@src), caption: @caption)
    end
  end

  def test_heading_anchors
    schema = Prosemirror::Schema.tiptap.with(Heading)
    json = doc({"type" => "heading", "attrs" => {"level" => 2}, "content" => [text("Café & co!")]},
      {"type" => "heading", "attrs" => {"level" => 2, "id" => "custom"}, "content" => [text("Other")]},
      {"type" => "heading", "attrs" => {"level" => 3}, "content" => [text("?")]})

    assert_equal '<h2 id="cafe-co">Café &amp; co!</h2><h2 id="custom">Other</h2><h3>?</h3>', render(json, schema: schema)
  end

  def test_render_your_own_components
    schema = Prosemirror::Schema.tiptap.with(ImageBlock)
    json = doc({"type" => "imageBlock", "attrs" => {"src" => "/a.png", "caption" => "A <b>photo</b>"}})

    assert_equal '<figure><img src="/a.png"><figcaption>A &lt;b&gt;photo&lt;/b&gt;</figcaption></figure>',
      render(json, schema: schema)
  end

  def test_skip_empty_paragraphs
    schema = Prosemirror::Schema.tiptap.with(SkipEmptyParagraphs)
    json = doc({"type" => "paragraph"}, paragraph(text("Hi")), paragraph(text(" ")))

    assert_equal "<p>Hi</p><p> </p>", render(json, schema: schema)
  end

  def test_skip_blank_paragraphs
    schema = Prosemirror::Schema.tiptap.with(SkipBlankParagraphs)
    json = doc({"type" => "paragraph"}, paragraph(text("Hi")), paragraph(text(" "), {"type" => "hardBreak"}),
      paragraph({"type" => "image", "attrs" => {"src" => "/a.png"}}))

    assert_equal '<p>Hi</p><p><img src="/a.png"></p>', render(json, schema: schema)
  end

  def test_remove_empty_paragraphs_before_saving
    item = ->(*content) { {"type" => "listItem", "content" => content} }
    json = doc({"type" => "paragraph", "attrs" => {"textAlign" => "center"}, "content" => [text("Hi")]}, {"type" => "paragraph"},
      {"type" => "bulletList", "content" => [item.call(paragraph(text(" "))), item.call(paragraph(text("a")))]},
      {"type" => "orderedList", "content" => [item.call({"type" => "paragraph"})]},
      {"type" => "bulletList", "content" => [item.call(paragraph, {"type" => "imageBlock", "attrs" => {"src" => "/a.png"}})]})

    schema = Prosemirror::Schema.tiptap(case: :camel, on_invalid: ->(_) {}).with(ImageBlock)
    document = Prosemirror.parse(json, schema:).transform do |node|
      case node
      in {type: :paragraph | :list_item} if node.blank?(schema) then nil
      in {type: :bullet_list | :ordered_list} if node.content.empty? then nil
      else node
      end
    end

    assert_equal ["paragraph", "bulletList", "bulletList"], document.to_h["content"].map { |node| node["type"] }
    assert_equal({"type" => "paragraph", "attrs" => {"textAlign" => "center"}, "content" => [text("Hi")]}, document.to_h.dig("content", 0))
    assert_equal [item.call(paragraph(text("a")))], document.to_h.dig("content", 1, "content")
    assert_equal "imageBlock", document.to_h.dig("content", 2, "content", 0, "content", -1, "type")
  end
end
