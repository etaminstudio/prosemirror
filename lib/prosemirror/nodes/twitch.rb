# frozen_string_literal: true

require "uri"

module Prosemirror
  module Nodes
    # Tiptap's Twitch embed. `src` is the URL of a video, clip or channel, rendered as an iframe of its embed
    # URL. Without a Twitch URL, it renders nothing. Twitch only plays embeds on the domain named by `parent`:
    # override `parent` in a subclass, as Tiptap's `parent` option, which defaults to `localhost`.
    class Twitch < NodeType
      # The URLs Tiptap accepts.
      URL = %r{\A(?:https?://)?(?:www\.)?(?:twitch\.tv|clips\.twitch\.tv)/(?:videos/\d+|\w+/clip/[\w-]+|[\w-]+/?)?(?:\?.*)?\z}

      group :block

      prop :src, _String(length: 1..), parse_html: ->(element) { Twitch.from_embed_url(element["src"])&.fetch(:src) || element["src"] }
      prop :width, _Integer?(1..), default: 640, &Coerce::INTEGER
      prop :height, _Integer?(1..), default: 480, &Coerce::INTEGER
      prop :autoplay, _Boolean, default: false, parse_html: ->(element) { Twitch.from_embed_url(element["src"])&.fetch(:autoplay) }
      prop :muted, _Boolean, default: false, parse_html: ->(element) { Twitch.from_embed_url(element["src"])&.fetch(:muted) }
      prop :time, _String?, parse_html: ->(element) { Twitch.from_embed_url(element["src"])&.fetch(:time) }

      # Tiptap's markup, `<div data-twitch-video><iframe>`, or an iframe of a Twitch embed URL. Not with a URL
      # it can't render.
      parse_html(tag: "iframe[src]") do |element|
        src = element["src"]
        (Twitch.from_embed_url(src) || (element.parent&.key?("data-twitch-video") && Twitch.identify(src))) ? {} : false
      end

      def view_template
        src = safe_url(self.class.embed_url(@src, parent:, autoplay: @autoplay, muted: @muted, time: @time))
        return unless src

        div(data_twitch_video: "") { iframe(src:, width: @width, height: @height, allowfullscreen: true) }
      end

      # The domain of the site the embed is on.
      def parent = "localhost"

      # The URL, as text that Markdown links. With `html: true`, the iframe.
      def to_markdown(markdown, _parent, _index)
        markdown.write(markdown.html? ? markdown.node_html(node) : "<#{markdown.url(@src)}>")
        markdown.close_block(node)
      end

      # The video, clip or channel of a Twitch URL, as `[kind, id]`, or nil.
      # @api private
      def self.identify(src)
        return unless src.match?(URL)

        path = src.split("?").first
        if (clip = path[%r{clips\.twitch\.tv/([\w-]+)}, 1] || path[%r{twitch\.tv/[\w-]+/clip/([\w-]+)}, 1])
          [:clip, clip]
        elsif (video = path[%r{twitch\.tv/videos/(\d+)}, 1])
          [:video, video]
        elsif (channel = path[%r{twitch\.tv/([\w-]+)/?\z}, 1])
          [:channel, channel]
        end
      end

      # The embed URL, as Tiptap builds it, or nil.
      # @api private
      def self.embed_url(src, parent:, autoplay: false, muted: false, time: nil)
        kind, id = identify(src)
        return unless kind

        options = {"autoplay" => ("true" if autoplay), "muted" => ("true" if muted)}
        query = if kind == :clip
          {"clip" => id, "parent" => parent, **options}
        else
          {kind.to_s => id, "parent" => parent, "allowfullscreen" => "true", **options, "time" => (time if kind == :video)}
        end
        base = (kind == :clip) ? "https://clips.twitch.tv/embed" : "https://player.twitch.tv/"
        "#{base}?#{URI.encode_www_form(query.compact)}"
      end

      # The URL and options of an embed URL, as Tiptap reads them, or nil.
      # @api private
      def self.from_embed_url(url)
        uri = URI.parse(url.to_s)
        return unless uri.is_a?(URI::HTTP)

        query = URI.decode_www_form(uri.query.to_s).to_h
        src = case [uri.host.to_s.delete_prefix("www."), uri.path]
        in ["player.twitch.tv", _]
          if query["video"] then "https://www.twitch.tv/videos/#{query["video"]}"
          elsif query["channel"] then "https://www.twitch.tv/#{query["channel"]}"
          end
        in ["clips.twitch.tv", "/embed"]
          query["clip"]&.then { |clip| "https://clips.twitch.tv/#{clip}" }
        else nil
        end
        {src:, autoplay: query["autoplay"] == "true", muted: query["muted"] == "true", time: query["time"]} if src&.match?(URL)
      rescue URI::Error, ArgumentError
        nil
      end
    end
  end
end
