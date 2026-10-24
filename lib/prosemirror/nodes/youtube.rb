# frozen_string_literal: true

require "uri"

module Prosemirror
  module Nodes
    # Tiptap's YouTube embed. `src` is the video's URL, like `https://www.youtube.com/watch?v=…`, rendered as
    # an iframe of its embed URL. Without a YouTube URL, it renders nothing. Override `embed_host` for
    # `https://www.youtube-nocookie.com`, as Tiptap's `nocookie` option.
    class Youtube < NodeType
      # The URLs Tiptap accepts: on youtube.com, youtu.be and youtube-nocookie.com.
      URL = %r{\A(?:(?:https?:)?//)?(?:(?:www|m|music)\.)?(?:youtube\.com|youtu\.be|youtube-nocookie\.com)(?:/(?:[\w-]+\?v=|embed/|v/)?)[\w-]+\S*\z}
      EMBED_HOSTS = %w[youtube.com youtube-nocookie.com].freeze

      group :block

      prop :src, _String(length: 1..), parse_html: ->(element) { Youtube.from_embed_url(element["src"])&.fetch(:src) || element["src"] }
      prop :start, _Integer(0..), default: 0,
        parse_html: ->(element) { Youtube.from_embed_url(element["src"])&.fetch(:start) }, &Coerce::INTEGER
      prop :width, _Integer?(1..), default: 640, &Coerce::INTEGER
      prop :height, _Integer?(1..), default: 480, &Coerce::INTEGER

      # Tiptap's markup, `<div data-youtube-video><iframe>`, or an iframe of a YouTube embed URL.
      parse_html(tag: "iframe[src]") do |element|
        (element.parent&.key?("data-youtube-video") || Youtube.from_embed_url(element["src"])) ? {} : false
      end

      def view_template
        src = safe_url(self.class.embed_url(@src, start: @start, host: embed_host))
        return unless src

        div(data_youtube_video: "") { iframe(src:, width: @width, height: @height, allowfullscreen: true) }
      end

      def embed_host = "https://www.youtube.com"

      # The URL, as text that Markdown links. With `html: true`, the iframe.
      def to_markdown(markdown, _parent, _index)
        markdown.write(markdown.html? ? markdown.node_html(node) : "<#{markdown.url(@src)}>")
        markdown.close_block(node)
      end

      # The embed URL of a video or playlist, as Tiptap builds it, or nil.
      def self.embed_url(src, start: 0, host: "https://www.youtube.com")
        return unless src.match?(URL)

        if (playlist = src[/[?&]list=([\w-]+)/, 1])
          return "#{host}/embed/videoseries?list=#{playlist}"
        end

        id = src[%r{(?:youtu\.be/|/embed/|/v/|/shorts/|/live/|[?&]v=)([\w-]+)}, 1]
        id && "#{host}/embed/#{id}#{"?start=#{start}" if start.positive?}"
      end

      # The video URL and start time of an embed URL, as Tiptap reads them, or nil.
      def self.from_embed_url(url)
        uri = URI.parse(url.to_s)
        return unless uri.is_a?(URI::HTTP) && EMBED_HOSTS.include?(uri.host.to_s.delete_prefix("www."))

        query = URI.decode_www_form(uri.query.to_s).to_h
        src = case uri.path
        when "/embed/videoseries" then query["list"]&.then { |list| "https://www.youtube.com/playlist?list=#{list}" }
        when %r{\A/embed/([\w-]+)\z} then "https://www.youtube.com/watch?v=#{Regexp.last_match(1)}"
        end
        {src:, start: query["start"].to_i} if src&.match?(URL)
      rescue URI::Error, ArgumentError
        nil
      end
    end
  end
end
