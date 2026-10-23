# frozen_string_literal: true

module Prosemirror
  module HTML
    # Decodes character references (`&amp;`, `&eacute;`, `&#233;`, `&#xE9;`) as HTML5 does, with the
    # WHATWG list of named references: https://html.spec.whatwg.org/multipage/named-characters.html
    module Entities
      # Code points 0x80 to 0x9F, read as Windows-1252, as browsers do.
      WINDOWS_1252 = {
        0x80 => 0x20AC, 0x82 => 0x201A, 0x83 => 0x0192, 0x84 => 0x201E, 0x85 => 0x2026, 0x86 => 0x2020,
        0x87 => 0x2021, 0x88 => 0x02C6, 0x89 => 0x2030, 0x8A => 0x0160, 0x8B => 0x2039, 0x8C => 0x0152,
        0x8E => 0x017D, 0x91 => 0x2018, 0x92 => 0x2019, 0x93 => 0x201C, 0x94 => 0x201D, 0x95 => 0x2022,
        0x96 => 0x2013, 0x97 => 0x2014, 0x98 => 0x02DC, 0x99 => 0x2122, 0x9A => 0x0161, 0x9B => 0x203A,
        0x9C => 0x0153, 0x9E => 0x017E, 0x9F => 0x0178
      }.freeze

      # The length of the longest reference without `;`, like `middot`.
      LONGEST_LEGACY_NAME = 6
      REFERENCE = /&(?:#(\d+);?|#[xX](\h+);?|([A-Za-z][A-Za-z0-9]*;?))/

      module_function

      # In an attribute, a named reference without a semicolon followed by a letter, a digit or `=`
      # stays as it is, as in browsers (`?a=1&copy=2` keeps `&copy`).
      def decode(string, attribute: false)
        return string unless string.include?("&")

        string.gsub(REFERENCE) do
          if (decimal = Regexp.last_match(1))
            character(decimal.to_i)
          elsif (hexadecimal = Regexp.last_match(2))
            character(hexadecimal.to_i(16))
          else
            named(Regexp.last_match(3), Regexp.last_match.post_match, attribute) || Regexp.last_match(0)
          end
        end
      end

      # The characters of a named reference ending with `;`, or nil. `entities.txt` has one reference per
      # line, with its code points in hexadecimal (`nvlt; 3C,20D2`). It is kept as one string, searched with
      # `index`, which takes a tenth of the memory of a Hash. The references found are cached, but not the
      # unknown names, which documents could make up without limit.
      def lookup(name)
        @found ||= {}
        @found[name] ||= begin
          start = list.index("\n#{name} ") or return nil
          characters(list[start + name.length + 2...list.index("\n", start + 1)])
        end
      end

      # The references without `;`, which browsers also read at the start of a longer name (`&copy2`).
      def legacy
        @legacy ||= list.scan(/^([A-Za-z0-9]+) ([\h,]+)$/).to_h { |name, codes| [name, characters(codes)] }.freeze
      end

      def list
        @list ||= "\n#{File.read(File.join(__dir__, "entities.txt"))}".freeze
      end

      def characters(codes)
        codes.split(",").map { |code| code.to_i(16) }.pack("U*").freeze
      end

      def character(code)
        return "�" if code.zero? || code > 0x10FFFF || (0xD800..0xDFFF).cover?(code)

        [WINDOWS_1252.fetch(code, code)].pack("U")
      end

      # The longest reference starting the name, followed by the rest of the name. A `;` can only end the
      # name, so a shorter reference is one without `;`.
      def named(name, following, attribute)
        return lookup(name) if name.end_with?(";") && lookup(name)

        [name.length, LONGEST_LEGACY_NAME].min.downto(1) do |length|
          next unless (characters = legacy[name[0, length]])

          rest = name[length..]
          return nil if attribute && "#{rest}#{following}".match?(/\A[A-Za-z0-9=]/)

          return characters + rest
        end
        nil
      end
    end
  end
end
