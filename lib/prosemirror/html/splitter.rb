# frozen_string_literal: true

require "strscan"

module Prosemirror
  module HTML
    # Splits HTML into pieces of about `size` bytes, between top-level elements, so Herb can parse
    # them one at a time: its memory grows to hundreds of times the size of the input it parses
    # (https://github.com/marcoroth/herb/issues/2839). Once Herb fixes it, this class can probably be removed.
    #
    # It only cuts where it can follow the structure: when a closing tag doesn't match the last open
    # element, as with unclosed or implicitly closed elements, the rest stays in one piece. HTML with
    # ERB tags isn't split, since Herb groups ERB blocks with the HTML between them.
    # @api private
    class Splitter
      # As Herb's lists.
      VOID_TAGS = %w[
        area base basefont bgsound br col embed frame hr img input keygen link meta param source track wbr
      ].to_set.freeze
      RAW_TEXT_TAGS = %w[script style iframe xmp noembed noframes textarea title].to_set.freeze

      NAME = /[a-zA-Z][^\s\/>]*/
      # The rest of an opening tag: attributes, with quoted values that can hold `>`.
      TAG_REST = /(?:[^>"']|"[^"]*"|'[^']*')*>/

      def initialize(size)
        @size = size
      end

      def call(html)
        return [html] if html.bytesize <= @size || html.include?("<%")

        pieces = []
        start = 0
        open = []
        scanner = StringScanner.new(html)
        until scanner.eos?
          break unless scanner.skip_until(/</)

          if scanner.skip(/!--/)
            break unless scanner.skip_until(/-->/)
          elsif scanner.skip(/[!?]/)
            break unless scanner.skip_until(/>/)
          elsif scanner.skip(%r{/(#{NAME})\s*>}o)
            break unless open.pop == lowercase(scanner[1])
          elsif scanner.skip(/(#{NAME})/o)
            name = lowercase(scanner[1])
            break unless scanner.skip(TAG_REST)

            if RAW_TEXT_TAGS.include?(name)
              break unless scanner.skip_until(%r{</#{Regexp.escape(name)}\s*>}i)
            elsif !VOID_TAGS.include?(name) && !self_closing?(html, scanner.pos)
              open << name
            end
          else
            next
          end

          if open.empty? && scanner.pos - start >= @size
            pieces << html.byteslice(start...scanner.pos)
            start = scanner.pos
          end
        end
        pieces << html.byteslice(start..) if start < html.bytesize
        pieces
      end

      private

      # Tag names are lowercase in most HTML: only the others are copied.
      def lowercase(name)
        name.match?(/[A-Z]/) ? name.downcase : name
      end

      # Whether the tag that ends before this byte position ends with `/>`, without copying it.
      def self_closing?(html, position)
        html.getbyte(position - 2) == 47 # "/"
      end
    end
  end
end
