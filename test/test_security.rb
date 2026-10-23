# frozen_string_literal: true

require "test_helper"

class TestSecurity < Minitest::Test
  include TestHelpers

  def link(href) = doc(paragraph(text("L", [{ "type" => "link", "attrs" => { "href" => href } }])))
  def image(src) = doc({ "type" => "image", "attrs" => { "src" => src } })

  # CVE-2025-64501: attribute values were not escaped.
  def test_escapes_attribute_values
    json = doc({ "type" => "image", "attrs" => { "src" => "a.png", "alt" => %("><script>alert(1)</script>) } })

    assert_equal %(<img src="a.png" alt="&quot;><script>alert(1)</script>">), render(json)
  end

  # GHSA-6gj3-5qf2-wwvv: attribute names came from the document.
  def test_ignores_attribute_names_from_the_document
    json = doc({ "type" => "heading", "attrs" => { "level" => 1, "onmouseover" => "alert(1)" },
                 "content" => [text("hi")] })

    assert_equal "<h1>hi</h1>", render(json)
  end

  def test_ignores_attribute_names_that_break_out_of_the_tag
    json = doc({ "type" => "heading", "attrs" => { "level" => 1, "onerror=alert(1) x" => "y" },
                 "content" => [text("hi")] })

    assert_equal "<h1>hi</h1>", render(json)
  end

  def test_ignores_event_handlers_on_links
    json = doc(paragraph(text("L", [{ "type" => "link",
                                      "attrs" => { "href" => "https://example.com", "onmouseover" => "alert(1)" } }])))

    assert_equal %(<p><a href="https://example.com">L</a></p>), render(json)
  end

  def test_ignores_event_handlers_on_images
    json = doc({ "type" => "image", "attrs" => { "src" => "a.png", "onerror" => "alert(1)" } })

    assert_equal %(<img src="a.png">), render(json)
  end

  # prosemirror_to_html 0.4.0: the heading level steered the tag name.
  def test_heading_level_cannot_change_the_tag
    json = doc({ "type" => "heading", "attrs" => { "level" => "1><script>alert(1)</script" },
                 "content" => [text("hi")] })

    assert_equal "<h1>hi</h1>", render(json)
  end

  def test_heading_level_out_of_range_uses_the_default
    json = doc({ "type" => "heading", "attrs" => { "level" => 7 }, "content" => [text("hi")] })

    assert_equal "<h1>hi</h1>", render(json)
  end

  def test_drops_dangerous_link_schemes
    [
      "javascript:alert(1)",
      "JavaScript:alert(1)",
      " javascript:alert(1)",
      "\u0001javascript:alert(1)",
      "java\tscript:alert(1)",
      "java\nscript:alert(1)",
      "data:text/html,<script>alert(1)</script>",
      "vbscript:msgbox(1)"
    ].each do |href|
      assert_equal "<p>L</p>", render(link(href)), "for #{href.inspect}"
    end
  end

  # Character references are escaped, so browsers read them as plain text: these are relative URLs.
  def test_keeps_character_references_in_urls_literal
    {
      "javascript&colon;alert(1)" => "javascript&amp;colon;alert(1)",
      "&#106;avascript:alert(1)" => "&amp;#106;avascript:alert(1)",
      "&#x6A;avascript:alert(1)" => "&amp;#x6A;avascript:alert(1)"
    }.each do |href, expected|
      assert_equal %(<p><a href="#{expected}">L</a></p>), render(link(href)), "for #{href.inspect}"
    end
  end

  def test_keeps_allowed_and_relative_urls
    {
      "https://example.com" => "https://example.com",
      "HTTP://example.com" => "HTTP://example.com",
      "mailto:a@example.com" => "mailto:a@example.com",
      "tel:+33100000000" => "tel:+33100000000",
      "/path?a=1&b=2" => "/path?a=1&amp;b=2",
      "#anchor" => "#anchor",
      "//example.com/a" => "//example.com/a",
      "page:with-colon/after-slash" => nil
    }.each do |href, expected|
      html = expected ? %(<p><a href="#{expected}">L</a></p>) : "<p>L</p>"

      assert_equal html, render(link(href)), "for #{href.inspect}"
    end
  end

  def test_drops_empty_urls
    assert_equal "<p>L</p>", render(link(""))
    assert_equal "", render(image(""))
  end

  def test_drops_images_with_dangerous_sources
    assert_equal "", render(image("javascript:alert(1)"))
    assert_equal "", render(image("data:image/svg+xml,<svg onload=alert(1)>"))
  end

  def test_url_schemes_are_configurable
    schema = Prosemirror::Schema.tiptap(url_schemes: %w[https])

    assert_equal "<p>L</p>", render(link("mailto:a@example.com"), schema: schema)
  end

  def test_highlight_color_cannot_inject_styles
    json = doc(paragraph(text("x", [{ "type" => "highlight",
                                      "attrs" => { "color" => "red; background-image: url(https://evil.example)" } }])))

    assert_equal "<p><mark>x</mark></p>", render(json)
  end

  def test_code_block_language_cannot_inject_classes
    json = doc({ "type" => "codeBlock", "attrs" => { "language" => %(x" onclick="alert(1)) },
                 "content" => [text("x")] })

    assert_equal "<pre><code>x</code></pre>", render(json)
  end

  def test_unknown_nodes_render_their_content_only
    json = doc({ "type" => "script", "attrs" => { "src" => "evil.js" }, "content" => [text("<b>x</b>")] })

    assert_equal "&lt;b&gt;x&lt;/b&gt;", render(json)
  end

  def test_rejects_deeply_nested_json_strings
    opening = '{"type":"blockquote","content":['
    json = "#{opening * 200}{\"type\":\"paragraph\"}#{"]}" * 200}"

    assert_raises(Prosemirror::InvalidDocument) { Prosemirror.parse(json) }
  end

  def test_cuts_deeply_nested_hashes
    json = { "type" => "paragraph" }
    200.times { json = { "type" => "blockquote", "content" => [json] } }
    reported = problems(json)

    assert(reported.any? { |message| message.include?("nested more than") })
  end
end
