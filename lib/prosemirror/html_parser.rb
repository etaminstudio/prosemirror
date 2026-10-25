# frozen_string_literal: true

module Prosemirror
  # Builds a document from HTML with the parse rules of the schema's node and mark types, as ProseMirror's
  # DOMParser does, from which this is ported: https://prosemirror.net/docs/ref/#model.DOMParser
  #
  # - whitespace is collapsed, except in nodes whose whitespace is preserved, like code blocks;
  # - content that doesn't fit where it is gets wrapped (text in a list becomes a list item with a
  #   paragraph), or moves up to a parent that accepts it;
  # - required content is filled in (an empty list item gets a paragraph);
  # - elements without a rule are unwrapped, and `head`, `noscript`, `object`, `script`, `style` and `title`
  #   are ignored.
  # @api private
  class HTMLParser
    BLOCK_TAGS = %w[
      address article aside blockquote canvas dd div dl fieldset figcaption figure footer form h1 h2 h3 h4 h5 h6
      header hgroup hr li noscript ol output p pre section table tfoot ul
    ].to_set.freeze
    IGNORE_TAGS = %w[head noscript object script style title].to_set.freeze
    LIST_TAGS = %w[ol ul].to_set.freeze

    PRESERVE_WS = 1
    PRESERVE_WS_FULL = 2

    WHITESPACE = /[ \t\r\n\f]/
    WHITESPACE_RUN = /[ \t\r\n\f]+/
    # Whitespace that collapsing changes: other than a single space.
    COLLAPSIBLE = /[\t\r\n\f]|  /

    # A rule that matched an element: the rule, its index, the attributes it gives, and the schema's type.
    Match = Data.define(:rule, :index, :attrs, :type)

    attr_reader :schema, :normalize_lists, :matched_styles

    def initialize(schema)
      @schema = schema
      rules = (schema.marks + schema.nodes).flat_map(&:parse_rules)
      rules = rules.each_with_index.sort_by { |rule, index| [-rule.priority, index] }.map(&:first)
      @tags = rules.select(&:tag)
      @selectors = @tags.map { |rule| HTML::Selector.parse(rule.tag) }
      # The indexes of the tag rules that can match an element with this name, in order.
      @candidates = Hash.new do |candidates, name|
        candidates[name] = @selectors.each_index.select { |index| @selectors[index].names.nil? || @selectors[index].names.include?(name) }.freeze
      end
      @styles = rules.select(&:style)
      @matched_styles = @styles.map(&:style_property).uniq
      @normalize_lists = @tags.none? { |rule| lists_contain_themselves?(rule) }
      @report = ->(message) { @schema.report(message, path: "html") }
    end

    # The document parsed from the HTML, as its top node.
    def parse(html)
      parse_element(HTML::Builder.new.call(html))
    end

    # The document for an Element's content, like the one HTML::Builder gives.
    def parse_element(root)
      context = Context.new(self)
      context.add_all(root, [])
      context.finish
    end

    # The first tag rule after `after` that matches the element in this context.
    def match_tag(element, context, after = nil)
      @candidates[element.name].each do |index|
        next if after && index <= after

        rule = @tags[index]
        next unless @selectors[index].match?(element)
        next if rule.context && !context.matches_context?(rule.context)

        match = build_match(rule, index, element) { |get_attrs| call_get_attrs(get_attrs, element) }
        return match if match
      end
      nil
    end

    # The first style rule after `after` that matches the property and value in this context.
    def match_style(property, value, context, after = nil)
      ((after ? after + 1 : 0)...@styles.size).each do |index|
        rule = @styles[index]
        next unless rule.style_matches?(property, value)
        next if rule.context && !context.matches_context?(rule.context)

        match = build_match(rule, index, nil) { |get_attrs| get_attrs.call(value) }
        return match if match
      end
      nil
    end

    # The schema's type for a rule: a subclass registered in the schema inherits its parent's rules.
    def type_for(rule)
      rule.node? ? @schema.node_type(rule.type.type_name) : @schema.mark_type(rule.type.type_name)
    end

    private

    def build_match(rule, index, element)
      type = type_for(rule)
      return nil unless type

      given = rule.attrs
      if rule.get_attrs
        result = yield(rule.get_attrs)
        return nil if result == false

        given = result.is_a?(Hash) ? result : nil
      end
      return Match.new(rule:, index:, attrs: nil, type:) if rule.ignore || rule.skip || rule.close_parent

      attrs = build_attrs(type, given, element)
      attrs && Match.new(rule:, index:, attrs:, type:)
    end

    # The rule's attributes, with the ones read from the element, built with the type's properties.
    def build_attrs(type, given, element)
      given = given ? given.transform_keys(&:to_s) : TypeDefinition::EMPTY_HASH
      if element
        from_html = type.attrs_from_html(element)
        given = given.empty? ? from_html : given.merge(from_html)
      end
      type.build_attrs(given, report: @report)
    end

    def call_get_attrs(get_attrs, element)
      (get_attrs.arity == 2) ? get_attrs.call(element, @schema) : get_attrs.call(element)
    end

    def lists_contain_themselves?(rule)
      return false unless rule.tag.match?(/\A(ul|ol)\b/) && rule.node?

      type = type_for(rule)
      type && @schema.content_match(type).match_type(type)
    end

    # A node being built: its type, attributes and marks, its content so far, and its content match state.
    class NodeContext
      attr_reader :type, :attrs, :marks, :solid, :content
      attr_accessor :match, :options

      def initialize(type, attrs, marks, solid, options, schema)
        @type = type
        @attrs = attrs
        @marks = marks
        @solid = solid
        @options = options
        @schema = schema
        @match = schema.content_match(type)
        @content = []
      end

      def find_wrapping(type)
        @match&.find_wrapping(type, @schema)
      end

      def finish
        strip_trailing_whitespace unless @options.anybits?(PRESERVE_WS)
        fill = @match&.fill_before(Node::EMPTY_ARRAY, @schema, to_end: true) || Node::EMPTY_ARRAY
        content = fill.empty? ? @content : @content + fill.filter_map { |type| @schema.create_and_fill(type) }
        # Frozen here, so that the node doesn't copy it: nothing else holds it.
        Node.new(type: @type.type_name, attrs: @attrs, content: Node.join_text(content).freeze, marks: @marks)
      end

      def inline_context?
        @schema.content_match(@type).inline_content?
      end

      private

      def strip_trailing_whitespace
        last = @content.last
        return unless last&.text? && (trailing = last.text[/#{WHITESPACE_RUN}\z/o])

        if trailing.length == last.text.length
          @content.pop
        else
          @content[-1] = last.with(text: last.text[0...-trailing.length])
        end
      end
    end

    # The state of one parse, as ProseMirror's ParseContext.
    class Context
      def initialize(parser)
        @parser = parser
        @schema = parser.schema
        @nodes = [NodeContext.new(@schema.node_type(@schema.top_node), @schema.node_type(@schema.top_node).default_attrs,
          [], true, 0, @schema)]
        @open = 0
        @needs_block = false
        @local_preserve_ws = false
        @linebreak = @schema.nodes.find(&:linebreak_replacement?)
      end

      def top
        @nodes[@open]
      end

      def add_all(parent, marks)
        parent.children.each { |child| add_dom(child, marks) }
      end

      def finish
        @open = 0
        close_extra
        @nodes.first.finish
      end

      # Whether the parents match a rule's context, as `"list_item/"`, `"blockquote//"` or `"a/|b/"`.
      def matches_context?(context)
        return context.split(/\s*\|\s*/).any? { |option| matches_context?(option) } if context.include?("|")

        parts = context.split("/", -1)
        context_matches?(parts, parts.size - 1, @open)
      end

      private

      def context_matches?(parts, index, depth)
        while index >= 0
          part = parts[index]
          if part.empty?
            if index == parts.size - 1 || index.zero?
              index -= 1
              next
            end
            return depth.downto(0).any? { |deeper| context_matches?(parts, index - 1, deeper) }
          end

          type = (depth >= 0) ? @nodes[depth].type : nil
          return false if type.nil? || (type.type_name.to_s != part && !type.group.include?(part.to_sym))

          depth -= 1
          index -= 1
        end
        true
      end

      def add_dom(dom, marks)
        dom.element? ? add_element(dom, marks) : add_text_node(dom, marks)
      end

      def add_text_node(dom, marks)
        value = dom.value
        top = self.top
        preserve = if top.options.anybits?(PRESERVE_WS_FULL)
          :full
        else
          @local_preserve_ws || top.options.anybits?(PRESERVE_WS)
        end
        return unless preserve == :full || top.inline_context? || value.match?(/[^ \t\r\n\f]/)

        if !preserve
          value = value.gsub(WHITESPACE_RUN, " ") if value.match?(COLLAPSIBLE)
          value = value[1..] if value.start_with?(" ") && @open == @nodes.size - 1 && strip_leading_space?(dom, top)
        elsif preserve == :full
          value = value.gsub(/\r\n?/, "\n")
        elsif @linebreak && value.match?(/[\r\n]/) && top.find_wrapping(@linebreak)
          value.split(/\r?\n|\r/, -1).each_with_index do |line, index|
            insert_node(Node.new(type: @linebreak.type_name, attrs: @linebreak.default_attrs), marks, true) if index.positive?
            insert_node(text_node(line), marks, !line.match?(/\S/)) unless line.empty?
          end
          value = ""
        else
          value = value.gsub(/\r?\n|\r/, " ")
        end
        insert_node(text_node(value), marks, !value.match?(/\S/)) unless value.empty?
      end

      # A leading space is dropped at the start of a node, after a line break, and after a space.
      def strip_leading_space?(dom, top)
        before = top.content.last
        previous = dom.parent&.previous_sibling(dom)
        before.nil? || (previous&.element? && previous.name == "br") || (before.text? && before.text.match?(/#{WHITESPACE}\z/o))
      end

      def add_element(dom, marks, match_after = nil)
        outer_ws = @local_preserve_ws
        top = self.top
        @local_preserve_ws = true if dom.name == "pre" || dom.style["white-space"].to_s.include?("pre")
        normalize_list(dom) if LIST_TAGS.include?(dom.name) && @parser.normalize_lists
        match = @parser.match_tag(dom, self, match_after)
        rule = match&.rule

        if rule ? rule.ignore : IGNORE_TAGS.include?(dom.name)
          ignore_fallback(dom, marks)
        elsif !rule || rule.skip || rule.close_parent
          add_element_without_rule(dom, marks, rule, top)
        else
          inner_marks = read_styles(dom, marks)
          add_element_by_rule(dom, match, inner_marks, rule.consuming ? nil : match.index) if inner_marks
        end
        @local_preserve_ws = outer_ws
      end

      def add_element_without_rule(dom, marks, rule, top)
        @open = [0, @open - 1].max if rule&.close_parent
        sync = false
        old_needs_block = @needs_block
        if BLOCK_TAGS.include?(dom.name)
          if top.content.any? && inline?(top.content.first) && @open.positive?
            @open -= 1
            top = self.top
          end
          sync = true
          @needs_block = true unless top.type
        elsif dom.children.empty?
          return leaf_fallback(dom, marks)
        end
        inner_marks = rule&.skip ? marks : read_styles(dom, marks)
        add_all(dom, inner_marks) if inner_marks
        self.sync(top) if sync
        @needs_block = old_needs_block
      end

      # A `br` without a rule becomes a newline, in nodes with inline content.
      def leaf_fallback(dom, marks)
        add_text_node(HTML::Text.new("\n"), marks) if dom.name == "br" && top.inline_context?
      end

      # An ignored `br` still starts inline content.
      def ignore_fallback(dom, marks)
        find_place(@schema.node_type(:text), marks, true) if dom.name == "br" && !top.inline_context?
      end

      # The marks with the ones from the element's styles, or nil when a style rule ignores the element.
      def read_styles(dom, marks)
        return marks if dom.style.empty?

        @parser.matched_styles.each do |property|
          value = dom.style[property]
          next if value.nil? || value.empty?

          after = nil
          while (match = @parser.match_style(property, value, self, after))
            return nil if match.rule.ignore

            marks = if match.rule.clear_mark
              marks.reject { |mark| clears?(match.rule.clear_mark, match.type, mark) }
            else
              marks + [Mark.new(type: match.type.type_name, attrs: match.attrs)]
            end
            break if match.rule.consuming

            after = match.index
          end
        end
        marks
      end

      def clears?(clear_mark, type, mark)
        (clear_mark == true) ? mark.type == type.type_name : clear_mark.call(mark)
      end

      def add_element_by_rule(dom, match, marks, continue_after)
        rule = match.rule
        type = match.type
        sync = false
        if rule.node?
          if !type.leaf?
            inner = enter(type, match.attrs, marks, rule.preserve_whitespace)
            if inner
              sync = true
              marks = inner
            end
          elsif !insert_node(Node.new(type: type.type_name, attrs: match.attrs), marks, dom.name == "br")
            leaf_fallback(dom, marks)
          end
        else
          marks += [Mark.new(type: type.type_name, attrs: match.attrs)]
        end
        start_in = top

        if rule.node? && type.leaf?
          # Leaves have no content to parse.
        elsif continue_after
          add_element(dom, marks, continue_after)
        elsif rule.get_content
          Array(rule.get_content.call(dom, @schema)).each { |node| insert_node(node, marks, false) }
        else
          add_all(content_element(dom, rule) || dom, marks)
        end
        @open -= 1 if sync && self.sync(start_in)
      end

      def content_element(dom, rule)
        case rule.content_element
        when String then dom.query(rule.content_element)
        when Proc then rule.content_element.call(dom)
        end
      end

      # Finds where a node of this type fits: in the open nodes, from the innermost, possibly with wrappers.
      # Returns the marks left to apply, or nil when it fits nowhere.
      def find_place(type, marks, cautious)
        route = nil
        sync_to = nil
        penalty = 0
        depth = @open
        # A loop rather than `downto`: breaking out of its block allocates.
        while depth >= 0
          context = @nodes[depth]
          depth -= 1
          found = context.find_wrapping(type)
          if found && (route.nil? || route.size > found.size + penalty)
            route = found
            sync_to = context
            break if found.empty?
          end
          next unless context.solid
          break if cautious

          penalty += 2
        end
        return nil unless route

        sync(sync_to)
        route.each { |wrapper| marks = enter_inner(wrapper, wrapper.default_attrs, marks, false) }
        marks
      end

      def insert_node(node, marks, cautious)
        type = node_type(node)
        inner_marks = find_place(type, marks, cautious)
        return false unless inner_marks

        close_extra
        top = self.top
        top.match &&= top.match.match_type(type)
        top.content << with_marks(node, inner_marks, top)
        true
      end

      # The node with the marks its parent allows, from the open marks and its own.
      def with_marks(node, marks, parent)
        return node if marks.empty? && node.marks.empty?

        node_marks = (marks + node.marks).each_with_object([]) do |mark, set|
          mark_type = @schema.mark_type(mark.type)
          set.replace(@schema.add_mark(mark, set)) if mark_type && parent.type.allows_mark?(mark_type, @schema)
        end
        (node_marks == node.marks) ? node : node.with(marks: node_marks.freeze)
      end

      def enter(type, attrs, marks, preserve_ws)
        inner_marks = find_place(type, marks, false)
        inner_marks && enter_inner(type, attrs, inner_marks, true, preserve_ws)
      end

      # Opens a node of this type. Returns the marks that don't apply to it, which apply to its content.
      def enter_inner(type, attrs, marks, solid, preserve_ws = nil)
        close_extra
        top = self.top
        top.match &&= top.match.match_type(type)
        options = ws_options(type, preserve_ws, top.options)
        applied = []
        remaining = marks.reject do |mark|
          mark_type = @schema.mark_type(mark.type)
          next false unless mark_type && top.type.allows_mark?(mark_type, @schema)

          applied = @schema.add_mark(mark, applied)
          true
        end
        @nodes << NodeContext.new(type, attrs, applied, solid, options, @schema)
        @open += 1
        remaining
      end

      def ws_options(type, preserve_ws, base)
        unless preserve_ws.nil?
          return (preserve_ws ? PRESERVE_WS : 0) | ((preserve_ws == :full) ? PRESERVE_WS_FULL : 0)
        end

        (type.whitespace == :pre) ? (PRESERVE_WS | PRESERVE_WS_FULL) : base
      end

      # Finishes the nodes above the open one, and adds them to their parents.
      def close_extra
        return if @nodes.size <= @open + 1

        (@nodes.size - 1).downto(@open + 1) { |index| @nodes[index - 1].content << @nodes[index].finish }
        @nodes.slice!((@open + 1)..)
      end

      # A loop rather than `downto`: returning from its block allocates, and this runs for each element.
      def sync(to)
        index = @open
        while index >= 0
          if @nodes[index].equal?(to)
            @open = index
            return true
          elsif @local_preserve_ws
            @nodes[index].options |= PRESERVE_WS
          end
          index -= 1
        end
        false
      end

      # Moves lists that directly follow a list item into it, as some tools produce them.
      def normalize_list(dom)
        previous_item = nil
        kept = []
        dom.children.each do |child|
          name = child.element? ? child.name : nil
          if name && LIST_TAGS.include?(name) && previous_item
            previous_item.append(child)
          else
            kept << child
            if name == "li"
              previous_item = child
            elsif name
              previous_item = nil
            end
          end
        end
        dom.children.replace(kept)
      end

      # The value is frozen in place, so that the node doesn't copy it: the parser made it, or the element
      # tree it parses holds it, unchanged.
      def text_node(value)
        Node.new(type: :text, text: value.freeze)
      end

      def node_type(node)
        @schema.node_type(node.type)
      end

      def inline?(node)
        node.text? || node_type(node)&.inline?
      end
    end
  end
end
