# frozen_string_literal: true

require "test_helper"

class TestResolveUrls < Minitest::Test
  include TestHelpers

  def link(text, href) = {"type" => "text", "text" => text, "marks" => [{"type" => "link", "attrs" => {"href" => href}}]}

  def image(src) = {"type" => "image", "attrs" => {"src" => src}}

  # Records looked up by GlobalID, as in an app: Page 2 doesn't exist.
  def resolver(calls)
    lambda do |urls|
      calls << urls
      urls.to_h { |url| [url, url.start_with?("gid://") ? url[%r{\Agid://app/Page/([13])\z}, 1]&.then { |id| "/pages/#{id}" } : url] }
    end
  end

  def test_all_urls_are_resolved_at_once
    calls = []
    reported = []
    schema = Prosemirror::Schema.tiptap(resolve_urls: resolver(calls), on_invalid: ->(error) { reported << error.message })
    document = schema.parse(doc(paragraph(link("a", "gid://app/Page/1"), text(" "), link("b", "gid://app/Page/2"), text(" "),
      link("c", "https://example.com"), text(" "), link("d", "gid://app/Page/1")), image("gid://app/Page/3")))

    assert_equal %(<p><a href="/pages/1">a</a> b <a href="https://example.com">c</a> <a href="/pages/1">d</a></p><img src="/pages/3">),
      document.to_html
    assert_equal [["gid://app/Page/1", "gid://app/Page/2", "https://example.com", "gid://app/Page/3"]], calls
    assert_equal ["URL could not be resolved: \"gid://app/Page/2\""], reported
  end

  # Each rendering resolves the URLs again: records may have changed.
  def test_each_rendering_resolves
    calls = []
    document = Prosemirror::Schema.tiptap(resolve_urls: resolver(calls)).parse(doc(paragraph(link("a", "gid://app/Page/1"))))
    2.times { document.to_html }

    assert_equal 2, calls.size
  end

  def test_documents_without_urls_dont_call_it
    calls = []
    Prosemirror::Schema.tiptap(resolve_urls: resolver(calls)).parse(doc(paragraph(text("a")))).to_html

    assert_empty calls
  end

  # URLs built while rendering, like a YouTube embed URL, are resolved one at a time.
  def test_urls_built_while_rendering
    calls = []
    html = Prosemirror::Schema.tiptap(resolve_urls: resolver(calls)).parse(doc({"type" => "youtube", "attrs" => {"src" => "https://youtu.be/abc"}})).to_html

    assert_includes html, %(src="https://www.youtube.com/embed/abc")
    assert_equal [["https://www.youtube.com/embed/abc"]], calls
  end

  def test_custom_types_declare_their_urls
    card = Class.new(Prosemirror::NodeType) do
      type_name :card
      group :block
      prop :url, _String?, url: true
      prop :title, _String?

      def view_template = a(href: safe_url(@url)) { @title }
    end
    calls = []
    schema = Prosemirror::Schema.tiptap(resolve_urls: resolver(calls)).with(card)
    document = schema.parse(doc({"type" => "card", "attrs" => {"url" => "gid://app/Page/1", "title" => "gid://app/Page/3"}}))

    assert_equal ["gid://app/Page/1"], document.urls
    assert_equal %(<a href="/pages/1">gid://app/Page/3</a>), document.to_html
    assert_equal [["gid://app/Page/1"]], calls
  end

  def test_resolve_url_and_resolve_urls_cant_be_used_together
    assert_raises(ArgumentError) { Prosemirror::Schema.tiptap(resolve_url: ->(url) { url }, resolve_urls: ->(urls) { {} }) }
  end
end
