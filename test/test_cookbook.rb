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

  class ListItem < Prosemirror::Nodes::ListItem
    def view_template(&)
      paragraph = node.content.first if node.content.size == 1
      return super unless paragraph&.type == :paragraph && paragraph.content.any?

      li { render_content(paragraph.content) }
    end
  end

  WORD = /[[:alnum:]]+(?:[-'’][[:alnum:]]+)*/

  def word_count(document)
    document.to_text.scan(WORD).size
  end

  class TableOfContents < Phlex::HTML
    def initialize(document)
      @document = document
    end

    def view_template
      nav do
        ul do
          @document.headings.each do |heading|
            li(class: "level-#{heading[:level]}") { a(href: "##{heading[:id]}") { heading[:text] } }
          end
        end
      end
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

  class ImageBlock < Prosemirror::NodeType
    group :block

    prop :src, String
    prop :caption, _String?

    def view_template
      render Figure.new(src: safe_url(@src), caption: @caption)
    end
  end

  def test_tight_lists
    item = ->(*content) { {"type" => "listItem", "content" => content} }
    list = ->(*items) { {"type" => "bulletList", "content" => items} }
    json = doc(list.call(item.call(paragraph(text("a", [{"type" => "bold"}]), text(" b"))),
      item.call(paragraph(text("c")), paragraph(text("d"))),
      item.call(paragraph(text("e")), list.call(item.call(paragraph(text("f"))))),
      item.call(paragraph)))

    assert_equal "<ul><li><strong>a</strong> b</li><li><p>c</p><p>d</p></li><li><p>e</p><ul><li>f</li></ul></li><li><p></p></li></ul>",
      render(json, schema: Prosemirror::Schema.tiptap.with(ListItem))
  end

  def test_table_of_contents
    document = Prosemirror.parse(doc({"type" => "heading", "attrs" => {"level" => 2}, "content" => [text("Setup")]},
      {"type" => "heading", "attrs" => {"level" => 3}, "content" => [text("Setup")]}))

    assert_equal %(<nav><ul><li class="level-2"><a href="#setup">Setup</a></li><li class="level-3"><a href="#setup-2">Setup</a></li></ul></nav>),
      TableOfContents.new(document).call
    assert_equal %(<h2 id="setup">Setup</h2><h3 id="setup-2">Setup</h3>), document.to_html(heading_ids: true)
  end

  def test_quotes_with_their_author
    schema = Prosemirror::Schema.tiptap.with(Blockquote)
    json = doc({"type" => "blockquote", "content" => [
      paragraph(text("To be ", [{"type" => "bold"}]), text("or not"), {"type" => "hardBreak"},
        text("Shakespeare"))
    ]})

    assert_equal "<figure><blockquote><strong>To be </strong>or not</blockquote>" \
                 "<figcaption>Shakespeare</figcaption></figure>", render(json, schema: schema)
  end

  def test_word_count
    document = Prosemirror.parse(doc({"type" => "heading", "attrs" => {"level" => 2}, "content" => [text("Two words")]},
      paragraph(text("L’été, c'est la saison — "), text("well-known", [{"type" => "bold"}]), text(" in 2026!")),
      {"type" => "codeBlock", "content" => [text("puts 1 + 2")]}))

    assert_equal 12, word_count(document)
    assert_equal 9, word_count(document.transform { |node| (node.type == :code_block) ? nil : node })
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
