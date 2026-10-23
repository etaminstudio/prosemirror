# frozen_string_literal: true

require "test_helper"

class TestCustomTypes < Minitest::Test
  include TestHelpers

  class ImageBlock < Prosemirror::NodeType
    group :block

    prop :src, String
    prop :caption, _String?
    prop :file_data, _String?

    def view_template
      figure do
        img(src: safe_url(@src))
        figcaption { @caption } if @caption
      end
    end
  end

  class Heading < Prosemirror::Nodes::Heading
    prop :text_align, _String?, json: "textAlign"

    def view_template(&)
      tag(:"h#{@level}", id: node.text_content.downcase.tr(" ", "-"), class: "heading", style: nil, &)
    end
  end

  # A quote whose last line, after a hard break, is the author.
  class Blockquote < Prosemirror::Nodes::Blockquote
    def view_template
      inline = node.content.flat_map(&:content)
      split = inline.rindex { |child| child.type == :hard_break }

      figure do
        blockquote { render_content(split ? inline[...split] : inline) }
        figcaption { render_content(inline[(split + 1)..]) } if split
      end
    end
  end

  class Mention < Prosemirror::NodeType
    group :inline
    inline
    leaf_text { |node| "@#{node.attrs[:label]}" }

    prop :label, String

    def view_template = span(class: "mention") { "@#{@label}" }
  end

  def test_custom_node_type
    schema = Prosemirror::Schema.tiptap.with(ImageBlock)
    json = doc({"type" => "imageBlock", "attrs" => {"src" => "/a.png", "caption" => "A <b>caption</b>"}})

    assert_equal '<figure><img src="/a.png"><figcaption>A &lt;b&gt;caption&lt;/b&gt;</figcaption></figure>',
      render(json, schema: schema)
  end

  def test_custom_attribute_names_are_kept
    schema = Prosemirror::Schema.tiptap(case: :camel).with(ImageBlock)
    json = doc({"type" => "imageBlock", "attrs" => {"src" => "/a.png", "file_data" => "{}"}})

    assert_equal({"src" => "/a.png", "caption" => nil, "file_data" => "{}"},
      Prosemirror.parse(json, schema: schema).to_h.dig("content", 0, "attrs"))
  end

  def test_replacing_a_built_in_type
    schema = Prosemirror::Schema.tiptap.with(Heading)
    json = doc({"type" => "heading", "attrs" => {"level" => 2, "textAlign" => "center"},
                 "content" => [text("Hello World")]})
    document = Prosemirror.parse(json, schema: schema)

    assert_equal '<h2 id="hello-world" class="heading">Hello World</h2>', document.to_html
    assert_equal({"level" => 2, "textAlign" => "center"}, document.to_h.dig("content", 0, "attrs"))
    assert_equal({level: 2, text_align: "center"}, document.content.first.attrs)
  end

  def test_rendering_parts_of_the_content
    schema = Prosemirror::Schema.tiptap.with(Blockquote)
    json = doc({"type" => "blockquote", "content" => [
      paragraph(text("To be ", [{"type" => "bold"}]), text("or not"), {"type" => "hardBreak"},
        text("Shakespeare"))
    ]})

    assert_equal "<figure><blockquote><strong>To be </strong>or not</blockquote>" \
                 "<figcaption>Shakespeare</figcaption></figure>", render(json, schema: schema)
  end

  def test_leaf_text
    schema = Prosemirror::Schema.tiptap.with(Mention)
    json = doc(paragraph(text("Hi "), {"type" => "mention", "attrs" => {"label" => "hans"}}))

    assert_equal "Hi @hans", Prosemirror.parse(json, schema: schema).to_text
    assert_equal '<p>Hi <span class="mention">@hans</span></p>', render(json, schema: schema)
  end

  def test_resolve_url
    schema = Prosemirror::Schema.tiptap(resolve_url: ->(url) { url.sub(%r{\Agid://app/Page/}, "/pages/") })
    json = doc(paragraph(text("x", [{"type" => "link", "attrs" => {"href" => "gid://app/Page/1"}}])))

    assert_equal '<p><a href="/pages/1">x</a></p>', render(json, schema: schema)
  end

  def test_resolve_url_reports_urls_it_cannot_resolve
    reported = []
    schema = Prosemirror::Schema.tiptap(resolve_url: ->(_) {}, on_invalid: ->(error) { reported << error.message })
    json = doc(paragraph(text("x", [{"type" => "link", "attrs" => {"href" => "gid://app/Page/0"}}])))

    assert_equal "<p>x</p>", render(json, schema: schema)
    assert_equal ['URL could not be resolved: "gid://app/Page/0"'], reported
  end

  # Phlex 2.4.1 checks attribute values against Date without loading it: https://github.com/yippee-fun/phlex/issues/974
  def test_array_attribute_values_without_rails
    callout = Class.new(Prosemirror::NodeType) do
      type_name :callout
      group :block
      content "inline*"

      def view_template(&) = aside(class: ["callout", "info"], &)
    end

    assert_equal %(<aside class="callout info">x</aside>),
      render({"type" => "doc", "content" => [{"type" => "callout", "content" => [text("x")]}]},
        schema: Prosemirror::Schema.tiptap.with(callout))
  end

  def test_type_names
    assert_equal :image_block, ImageBlock.type_name
    assert_equal :heading, Heading.type_name
    assert_equal :table_header, Prosemirror::Nodes::TableHeader.type_name
  end

  def test_with_rejects_other_classes
    assert_raises(ArgumentError) { Prosemirror::Schema.tiptap.with(String) }
  end

  def test_default_schema
    original = Prosemirror.schema
    Prosemirror.schema = Prosemirror::Schema.tiptap.with(ImageBlock)

    assert_equal '<figure><img src="/a.png"></figure>',
      Prosemirror.parse(doc({"type" => "image_block", "attrs" => {"src" => "/a.png"}})).to_html
  ensure
    Prosemirror.schema = original
  end

  def test_rendering_inside_a_phlex_component
    document = Prosemirror.parse(doc(paragraph(text("x"))))
    page = Class.new(Phlex::HTML) do
      define_method(:view_template) { article { render document.to_phlex } }
    end

    assert_equal "<article><p>x</p></article>", page.new.call
  end

  # Rails' `render` calls `render_in` with the view context.
  def test_rendering_with_rails
    document = Prosemirror.parse(doc(paragraph(text("x"))))

    assert_equal "<p>x</p>", document.render_in(Object.new)
  end
end
