# frozen_string_literal: true

require "test_helper"

class TestEmbeds < Minitest::Test
  include TestHelpers

  def schema = Prosemirror::Schema.tiptap(case: :camel, on_invalid: ->(_) {})

  def youtube(src, **attrs) = {"type" => "youtube", "attrs" => {"src" => src, **attrs.transform_keys(&:to_s)}}

  def twitch(src, **attrs) = {"type" => "twitch", "attrs" => {"src" => src, **attrs.transform_keys(&:to_s)}}

  def iframe_src(json, schema: self.schema) = schema.parse(doc(json)).to_html[/src="([^"]*)"/, 1]&.gsub("&amp;", "&")

  # Videos, shorts, live streams and playlists, from any of YouTube's URLs.
  def test_youtube_embed_urls
    {
      "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=5" => "https://www.youtube.com/embed/dQw4w9WgXcQ",
      "https://youtu.be/dQw4w9WgXcQ" => "https://www.youtube.com/embed/dQw4w9WgXcQ",
      "https://m.youtube.com/shorts/abc_DEF-1" => "https://www.youtube.com/embed/abc_DEF-1",
      "https://www.youtube.com/live/abc" => "https://www.youtube.com/embed/abc",
      "https://www.youtube-nocookie.com/embed/abc" => "https://www.youtube.com/embed/abc",
      "https://www.youtube.com/playlist?list=PL1" => "https://www.youtube.com/embed/videoseries?list=PL1"
    }.each do |src, embed|
      assert_equal embed, iframe_src(youtube(src)), src
    end
    assert_equal "https://www.youtube.com/embed/abc?start=30", iframe_src(youtube("https://youtu.be/abc", start: 30))
  end

  def test_twitch_embed_urls
    {
      "https://www.twitch.tv/videos/123" => "https://player.twitch.tv/?video=123&parent=localhost&allowfullscreen=true",
      "https://www.twitch.tv/somechannel" => "https://player.twitch.tv/?channel=somechannel&parent=localhost&allowfullscreen=true",
      "https://www.twitch.tv/somechannel/clip/Funny-1" => "https://clips.twitch.tv/embed?clip=Funny-1&parent=localhost",
      "https://clips.twitch.tv/Funny-1" => "https://clips.twitch.tv/embed?clip=Funny-1&parent=localhost"
    }.each do |src, embed|
      assert_equal embed, iframe_src(twitch(src)), src
    end
    assert_equal "https://player.twitch.tv/?video=123&parent=localhost&allowfullscreen=true&autoplay=true&muted=true&time=1m",
      iframe_src(twitch("https://www.twitch.tv/videos/123", autoplay: true, muted: true, time: "1m"))
  end

  # The iframe's URL is built from the video's id: other URLs render nothing.
  def test_other_urls_render_nothing
    ["https://example.com/watch?v=abc", "javascript:alert(1)//youtube.com/embed/x", "https://youtube.com.example.com/embed/abc"].each do |src|
      assert_equal "", schema.parse(doc(youtube(src))).to_html, src
    end
    assert_equal "", schema.parse(doc(twitch("https://example.com/videos/1"))).to_html
  end

  def test_subclasses_set_the_youtube_host_and_the_twitch_parent
    youtube_type = Class.new(Prosemirror::Nodes::Youtube) do
      type_name :youtube
      def embed_host = "https://www.youtube-nocookie.com"
    end
    twitch_type = Class.new(Prosemirror::Nodes::Twitch) do
      type_name :twitch
      def parent = "example.com"
    end
    custom = schema.with(youtube_type, twitch_type)

    assert_equal "https://www.youtube-nocookie.com/embed/abc", iframe_src(youtube("https://youtu.be/abc"), schema: custom)
    assert_equal "https://player.twitch.tv/?channel=c&parent=example.com&allowfullscreen=true", iframe_src(twitch("https://www.twitch.tv/c"), schema: custom)
  end

  # Iframes of embed URLs without Tiptap's `<div>`, as other editors write them, which Tiptap doesn't read.
  def test_iframes_without_tiptaps_markup
    html = %(<iframe src="https://www.youtube.com/embed/abc?start=4" width="560" height="315"></iframe><iframe src="https://player.twitch.tv/?channel=c&parent=x"></iframe><iframe src="https://example.com/"></iframe>)

    assert_equal [youtube("https://www.youtube.com/watch?v=abc", start: 4, width: 560, height: 315),
      twitch("https://www.twitch.tv/c", width: 640, height: 480, autoplay: false, muted: false, time: nil)],
      Prosemirror.from_html(html, schema:).to_h["content"]
  end

  # Tiptap keeps `"100%"`: HTML's `width` only takes integers.
  def test_dimensions_are_integers
    html = %(<div data-youtube-video><iframe src="https://www.youtube.com/embed/abc" width="100%"></iframe></div>)

    assert_equal 640, Prosemirror.from_html(html, schema:).to_h.dig("content", 0, "attrs", "width")
  end

  # A link to the video, or with `html: true`, the iframe, which Markdown import reads back.
  def test_markdown
    document = schema.parse(doc(youtube("https://www.youtube.com/watch?v=abc"), twitch("https://www.twitch.tv/videos/1")))

    assert_equal "<https://www.youtube.com/watch?v=abc>\n\n<https://www.twitch.tv/videos/1>\n", document.to_markdown
    assert_equal document.to_h, schema.from_markdown(document.to_markdown(html: true)).to_h
  end
end
