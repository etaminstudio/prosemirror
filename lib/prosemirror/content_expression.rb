# frozen_string_literal: true

module Prosemirror
  # A parsed content expression, such as `"paragraph block*"` or `"(table_cell | table_header){1,5}"`.
  # See https://prosemirror.net/docs/guide/#schema.content_expressions
  class ContentExpression
    TOKEN = /\s*(\w+|[()|+*?]|\{\s*\d+\s*(?:,\s*\d*\s*)?\})/

    attr_reader :source, :tree

    def initialize(source)
      @source = source
      @tokens = tokenize(source)
      @tree = parse_choice
      raise ArgumentError, "unexpected #{@tokens.first.inspect} in content expression #{source.inspect}" if @tokens.any?
    end

    # The node names and group names the expression refers to.
    def names
      collect_names(@tree)
    end

    private

    def tokenize(source)
      tokens = []
      rest = source.strip
      until rest.empty?
        match = TOKEN.match(rest)
        raise ArgumentError, "invalid content expression #{source.inspect}" unless match&.begin(0)&.zero?

        tokens << match[1]
        rest = match.post_match.strip
      end
      tokens
    end

    def parse_choice
      branches = [parse_sequence]
      while @tokens.first == "|"
        @tokens.shift
        branches << parse_sequence
      end
      branches.size == 1 ? branches.first : [:choice, branches]
    end

    def parse_sequence
      terms = []
      terms << parse_repeat while @tokens.any? && !["|", ")"].include?(@tokens.first)
      raise ArgumentError, "empty content expression in #{@source.inspect}" if terms.empty?

      terms.size == 1 ? terms.first : [:sequence, terms]
    end

    def parse_repeat
      atom = parse_atom
      case @tokens.first
      when "*" then @tokens.shift && [:repeat, atom, 0, nil]
      when "+" then @tokens.shift && [:repeat, atom, 1, nil]
      when "?" then @tokens.shift && [:repeat, atom, 0, 1]
      when /\A\{/ then [:repeat, atom, *parse_range(@tokens.shift)]
      else atom
      end
    end

    def parse_range(token)
      min, comma, max = token.delete("{} ").partition(",")
      return [min.to_i, min.to_i] if comma.empty?

      [min.to_i, max.empty? ? nil : max.to_i]
    end

    def parse_atom
      token = @tokens.shift
      case token
      when "("
        expression = parse_choice
        raise ArgumentError, "missing ) in content expression #{@source.inspect}" unless @tokens.shift == ")"

        expression
      when /\A\w+\z/ then [:name, token.to_sym]
      else raise ArgumentError, "unexpected #{token.inspect} in content expression #{@source.inspect}"
      end
    end

    def collect_names(tree)
      case tree.first
      when :name then [tree[1]]
      when :repeat then collect_names(tree[1])
      else tree[1].flat_map { |child| collect_names(child) }.uniq
      end
    end
  end
end
