# frozen_string_literal: true

module Prosemirror
  module HTML
    # The CSS selectors parse rules need, matched against one element: lists of compound selectors,
    # with a type (`p`, `*`), `#id`, `.class`, attribute selectors (`[href]`, `[a=b]`, `[a^=b]`,
    # `[a$=b]`, `[a*=b]`, `[a~=b]`, `[a|=b]`) and `:not(…)`. Combinators aren't supported.
    class Selector
      IDENTIFIER = /-?[_a-zA-Z][-\w]*/
      ATTRIBUTE = /\[\s*(#{IDENTIFIER})\s*(?:([~|^$*]?=)\s*(?:"([^"]*)"|'([^']*)'|(#{IDENTIFIER}))\s*)?\]/

      def self.parse(source)
        (@cache ||= {})[source] ||= new(source)
      end

      def initialize(source)
        @source = source
        @compounds = source.split(",").map { |part| parse_compound(part.strip) }
      end

      def match?(element)
        @compounds.any? { |tests| tests.all? { |test| test.call(element) } }
      end

      private

      def parse_compound(part)
        invalid! if part.empty?

        tests = []
        rest = part
        if (type = rest[/\A(?:\*|#{IDENTIFIER})/o])
          tests << ->(element) { element.name == type.downcase } unless type == "*"
          rest = rest[type.length..]
        end
        until rest.empty?
          test, length = parse_simple(rest)
          tests << test
          rest = rest[length..]
        end
        tests
      end

      # A simple selector at the start of `rest`, as a test and the length it takes.
      def parse_simple(rest)
        if (match = /\A#(#{IDENTIFIER})/o.match(rest))
          [id_test(match[1]), match[0].length]
        elsif (match = /\A\.(#{IDENTIFIER})/o.match(rest))
          [class_test(match[1]), match[0].length]
        elsif (match = /\A#{ATTRIBUTE}/o.match(rest))
          [attribute_test(*match.captures), match[0].length]
        elsif (match = /\A:not\(([^()]*)\)/.match(rest))
          [not_test(parse_compound(match[1].strip)), match[0].length]
        else
          invalid!
        end
      end

      def id_test(id)
        ->(element) { element["id"] == id }
      end

      def class_test(name)
        ->(element) { element.classes.include?(name) }
      end

      def attribute_test(name, operator, double_quoted, single_quoted, bare)
        name = name.downcase
        expected = double_quoted || single_quoted || bare
        lambda do |element|
          value = element[name]
          next false if value.nil?

          case operator
          when nil then true
          when "=" then value == expected
          when "^=" then !expected.empty? && value.start_with?(expected)
          when "$=" then !expected.empty? && value.end_with?(expected)
          when "*=" then !expected.empty? && value.include?(expected)
          when "~=" then value.split.include?(expected)
          when "|=" then value == expected || value.start_with?("#{expected}-")
          end
        end
      end

      def not_test(tests)
        ->(element) { !tests.all? { |test| test.call(element) } }
      end

      def invalid!
        raise ArgumentError, "unsupported selector #{@source.inspect}: only compound selectors, without combinators"
      end
    end
  end
end
