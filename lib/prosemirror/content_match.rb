# frozen_string_literal: true

module Prosemirror
  # A state of a node type's content expression, compiled into a deterministic automaton, as in
  # ProseMirror's ContentMatch: https://prosemirror.net/docs/ref/#model.ContentMatch
  #
  # Edges go from one state to the next for a node type. Their order matters: the first generatable
  # type is used to fill required content.
  # @api private
  class ContentMatch
    attr_reader :edges

    def initialize(valid_end)
      @valid_end = valid_end
      @edges = []
      @wrappings = {}
    end

    # Compiles a content expression for a schema. Returns EMPTY for leaf types.
    def self.compile(expression, schema)
      return EMPTY if expression.nil?

      Compiler.new(expression, schema).call
    end

    # Whether the content can end here.
    def valid_end?
      @valid_end
    end

    # The state after a node of this type, or nil when it can't come here.
    def match_type(type)
      @edges.find { |edge_type, _| edge_type == type }&.last
    end

    # The state after these node types, or nil when they don't match.
    def match_types(types)
      return self if types.empty?

      types.reduce(self) { |match, type| match&.match_type(type) }
    end

    def inline_content?
      !@edges.empty? && @edges.first.first.inline?
    end

    # The first type that can come here and can be created empty, or nil.
    def default_type(schema)
      @edges.map(&:first).find { |type| generatable?(type, schema) }
    end

    # The node types to insert before `types` so that they match, possibly none, or nil when no
    # insertion works. With `to_end`, the content must also be able to end after them.
    def fill_before(types, schema, to_end: false)
      # Most content needs nothing: no search.
      finished = match_types(types)
      return Node::EMPTY_ARRAY if finished && (!to_end || finished.valid_end?)

      seen = [self]
      search = lambda do |match, filled|
        finished = match.match_types(types)
        return filled if finished && (!to_end || finished.valid_end?)

        match.edges.each do |type, following|
          next if !generatable?(type, schema) || seen.include?(following)

          seen << following
          found = search.call(following, filled + [type])
          return found if found
        end
        nil
      end
      search.call(self, [])
    end

    # The wrapper types that let a node of this type come here, possibly none, or nil when none do.
    def find_wrapping(target, schema)
      return @wrappings[target] if @wrappings.key?(target)

      @wrappings[target] = compute_wrapping(target, schema)
    end

    def generatable?(type, schema)
      type.type_name != :text && !type.required_attrs?
    end

    private

    def compute_wrapping(target, schema)
      seen = {}
      active = [[self, nil, nil]]
      until active.empty?
        current = active.shift
        match, type, = current
        return wrapping_path(current) if match.match_type(target)

        match.edges.each do |next_type, following|
          next if next_type.leaf? || next_type.required_attrs? || seen[next_type]
          next if type && !following.valid_end?

          active << [schema.content_match(next_type), next_type, current]
          seen[next_type] = true
        end
      end
      nil
    end

    def wrapping_path(step)
      path = []
      while step && step[1]
        path.unshift(step[1])
        step = step[2]
      end
      path
    end

    EMPTY = new(true)

    # Compiles an expression tree into a non-deterministic automaton, then a deterministic one.
    class Compiler
      def initialize(expression, schema)
        @expression = expression
        @schema = schema
        @nfa = [[]]
      end

      def call
        connect(compile(@expression.tree, 0), new_state)
        explore(null_from(0), {})
      end

      private

      Edge = Struct.new(:term, :to)

      def new_state
        @nfa << []
        @nfa.size - 1
      end

      def edge(from, to = nil, term = nil)
        Edge.new(term, to).tap { |created| @nfa[from] << created }
      end

      def connect(edges, to)
        edges.each { |created| created.to = to }
      end

      def compile(tree, from)
        case tree.first
        when :choice then tree[1].flat_map { |branch| compile(branch, from) }
        when :sequence then compile_sequence(tree[1], from)
        when :repeat then compile_repeat(*tree.drop(1), from)
        when :name then resolve(tree[1]).map { |type| edge(from, nil, type) }
        end
      end

      def compile_sequence(parts, from)
        parts.each_with_index do |part, index|
          edges = compile(part, from)
          return edges if index == parts.size - 1

          connect(edges, from = new_state)
        end
      end

      def compile_repeat(tree, min, max, from)
        if min.zero? && max.nil? # *
          loop_state = new_state
          edge(from, loop_state)
          connect(compile(tree, loop_state), loop_state)
          [edge(loop_state)]
        elsif min == 1 && max.nil? # +
          loop_state = new_state
          connect(compile(tree, from), loop_state)
          connect(compile(tree, loop_state), loop_state)
          [edge(loop_state)]
        elsif min.zero? && max == 1 # ?
          [edge(from)] + compile(tree, from)
        else
          compile_range(tree, min, max, from)
        end
      end

      def compile_range(tree, min, max, from)
        current = from
        min.times do
          following = new_state
          connect(compile(tree, current), following)
          current = following
        end
        if max.nil?
          connect(compile(tree, current), current)
        else
          (max - min).times do
            following = new_state
            edge(current, following)
            connect(compile(tree, current), following)
            current = following
          end
        end
        [edge(current)]
      end

      def resolve(name)
        types = @schema.node_types_named(name)
        raise ArgumentError, "no node type or group #{name} in content expression #{@expression.source.inspect}" if types.empty?

        types
      end

      # The states reachable from `state` without consuming a node, sorted.
      def null_from(state)
        result = []
        scan = lambda do |current|
          edges = @nfa[current]
          return scan.call(edges.first.to) if edges.size == 1 && edges.first.term.nil?

          result << current
          edges.each { |created| scan.call(created.to) if created.term.nil? && !result.include?(created.to) }
        end
        scan.call(state)
        result.sort.reverse
      end

      def explore(states, labeled)
        out = []
        states.each do |state|
          @nfa[state].each do |created|
            next unless created.term

            set = out.find { |type, _| type == created.term }&.last
            null_from(created.to).each do |reached|
              out << [created.term, set = []] unless set
              set << reached unless set.include?(reached)
            end
          end
        end
        match = labeled[states.join(",")] = ContentMatch.new(states.include?(@nfa.size - 1))
        out.each do |type, set|
          set = set.sort.reverse
          match.edges << [type, labeled[set.join(",")] || explore(set, labeled)]
        end
        match
      end
    end
  end
end
