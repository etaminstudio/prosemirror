# frozen_string_literal: true

# Tiptap documents to measure, built the same way on every run: a page, as a CMS stores them, and a long
# document made of 50 pages. They use every built-in type, with marks, links and nested lists.
module Documents
  WORDS = %w[
    the editor stores each document as JSON with its paragraphs headings lists tables and images
    rendering turns it into HTML for the page while import reads content written elsewhere
    marks like bold italic and links apply to runs of text across the nodes of a paragraph
  ].freeze

  module_function

  def page(seed = 0)
    random = Random.new(seed)
    words = ->(count) { Array.new(count) { WORDS.sample(random: random) }.join(" ") }
    text = ->(value, *marks) { {"type" => "text", "text" => value, "marks" => (marks unless marks.empty?)}.compact }
    paragraph = lambda do
      {"type" => "paragraph", "content" => [
        text.call("#{words.call(12).capitalize} "),
        text.call(words.call(3), {"type" => "bold"}),
        text.call(" #{words.call(8)} "),
        text.call(words.call(2), {"type" => "link", "attrs" => {"href" => "https://example.com/#{random.rand(100)}"}}),
        text.call(" #{words.call(10)} "),
        text.call(words.call(2), {"type" => "italic"}),
        text.call(".")
      ]}
    end
    item = ->(*content) { {"type" => "listItem", "content" => content} }

    {"type" => "doc", "content" => [
      {"type" => "heading", "attrs" => {"level" => 2}, "content" => [text.call(words.call(5).capitalize)]},
      paragraph.call, paragraph.call,
      {"type" => "bulletList", "content" => [
        item.call(paragraph.call),
        item.call(paragraph.call, {"type" => "orderedList", "attrs" => {"start" => 1}, "content" => [item.call(paragraph.call), item.call(paragraph.call)]}),
        item.call(paragraph.call)
      ]},
      {"type" => "image", "attrs" => {"src" => "/images/#{random.rand(100)}.jpg", "alt" => words.call(4)}},
      {"type" => "heading", "attrs" => {"level" => 3}, "content" => [text.call(words.call(4).capitalize)]},
      paragraph.call,
      {"type" => "blockquote", "content" => [paragraph.call]},
      {"type" => "codeBlock", "attrs" => {"language" => "ruby"}, "content" => [text.call("doc = Prosemirror.parse(json)\ndoc.to_html")]},
      {"type" => "table", "content" => Array.new(3) do |row|
        {"type" => "tableRow", "content" => Array.new(3) do
          {"type" => row.zero? ? "tableHeader" : "tableCell", "content" => [{"type" => "paragraph", "content" => [text.call(words.call(2))]}]}
        end}
      end},
      {"type" => "taskList", "content" => [
        {"type" => "taskItem", "attrs" => {"checked" => true}, "content" => [paragraph.call]},
        {"type" => "taskItem", "attrs" => {"checked" => false}, "content" => [paragraph.call]}
      ]},
      {"type" => "paragraph", "content" => [text.call("Thanks "), {"type" => "mention", "attrs" => {"id" => "1", "label" => "Ada"}}, {"type" => "hardBreak"}, text.call(words.call(6))]},
      {"type" => "horizontalRule"},
      paragraph.call
    ]}
  end

  def long
    {"type" => "doc", "content" => Array.new(50) { |seed| page(seed)["content"] }.flatten(1)}
  end
end
