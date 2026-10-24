# frozen_string_literal: true

module Prosemirror
  # Writes a document as Markdown, as prosemirror-markdown's MarkdownSerializerState, from which this is
  # ported: https://github.com/ProseMirror/prosemirror-markdown
  #
  # Node types write themselves in `to_markdown`, with the methods of this class, and mark types declare
  # their syntax with `markdown`. Formatting without Markdown syntax, like underline, keeps only its text,
  # or becomes HTML with `html: true`.
  class MarkdownSerializer
    # No syntax: the mark's text only.
    BLANK_MARK = {open: "", close: "", mixable: true}.freeze
    # Unicode spaces, as CommonMark's flanking rules count them, non-breaking spaces included.
    SPACES_START = /\A[[:space:]]*/
    SPACES_ONLY = /\A[[:space:]]*\z/
    # Stands for the content when rendering a mark's HTML, to split it into its opening and closing tags.
    CONTENT = "\u0000"
    # `[text](href "title")`, or `<href>` when the text is the URL.
    LINK = {
      open: lambda { |markdown, mark, parent, index|
        markdown.in_autolink = markdown.plain_url?(mark, parent, index)
        markdown.in_autolink ? "<" : "["
      },
      close: lambda { |markdown, mark, _parent, _index|
        autolink = markdown.in_autolink
        markdown.in_autolink = nil
        autolink ? ">" : "](#{markdown.url(mark.attrs[:href])}#{markdown.title(mark.attrs[:title])})"
      },
      mixable: true
    }.freeze
    # Inline code, with more backticks than the code holds.
    CODE = {
      open: ->(markdown, _mark, parent, index) { markdown.backticks_for(parent.content[index], -1) },
      close: ->(markdown, _mark, parent, index) { markdown.backticks_for(parent.content[index - 1], 1) },
      escape: false
    }.freeze

    attr_reader :schema, :out
    attr_accessor :in_autolink, :in_tight_list

    def initialize(schema, html: false)
      @schema = schema
      @html = html
      @delim = +""
      @out = +""
      @closed = nil
      @in_autolink = nil
      @at_block_start = false
      @in_tight_list = false
      @html_marks = {}
    end

    # The document's content as Markdown, ending with a newline.
    def call(root)
      render_content(root)
      @out.empty? ? @out : @out.sub(/\n*\z/, "\n")
    end

    # Whether formatting without Markdown syntax is written as HTML.
    def html?
      @html
    end

    # Render a block, prefixing each line with `delim`, and the first one with `first_delim`. `node` is closed
    # at the end of the block.
    def wrap_block(delim, first_delim, node)
      old = @delim
      write(first_delim || delim)
      @delim += delim
      yield
      @delim = old
      close_block(node)
    end

    def ensure_new_line
      @out << "\n" unless at_blank?
    end

    # Writes the content as it is, after closing the previous block and adding the current delimiters.
    def write(content = nil)
      flush_close
      @out << @delim if !@delim.empty? && at_blank?
      @out << content if content
    end

    def close_block(node)
      @closed = node
    end

    # Writes text, escaped unless `escape` is false.
    def text(text, escape: true)
      lines = text.split("\n", -1)
      lines.each_with_index do |line, index|
        write
        # Markdown drops spaces at the start of a block, and after a hard break.
        line = line.lstrip if escape && index.zero? && (@at_block_start || @out.end_with?("\\\n#{@delim}"))
        # An exclamation mark before a link would make it an image.
        @out << "\\!" if !escape && line.start_with?("[") && @out.end_with?("!") && !@out.end_with?("\\!") && @out.chop!
        @out << (escape ? esc(line, start_of_line: @at_block_start) : line)
        @out << "\n" unless index == lines.size - 1
      end
    end

    # Renders a node with its type's `to_markdown`.
    def render(node, parent, index)
      type = @schema.node_type(node.type)
      if type
        component = type.new(**node.attrs)
        component.instance_variable_set(:@_prosemirror_node, node)
        component.instance_variable_set(:@_prosemirror_schema, @schema)
        component.to_markdown(self, parent, index)
      elsif !node.content.empty?
        render_content(node)
        close_block(node)
      end
    end

    # Renders the content of `parent` as blocks.
    def render_content(parent)
      parent.content.each_with_index { |node, index| render(node, parent, index) }
    end

    # Renders the content of `parent` as inline content, with its marks.
    def render_inline(parent, from_block_start: true)
      parent = without_unflanked_marks(parent)
      @at_block_start = from_block_start
      active = []
      trailing = +""
      progress = lambda do |node, index|
        marks = node ? node.marks : []

        # Marks on a final hard break would put a newline just before their closing syntax.
        if node && hard_break?(node)
          marks = marks.select do |mark|
            following = parent.content[index + 1]
            following&.marks&.include?(mark) && (!following.text? || following.text.match?(/\S/))
          end
        end

        leading = trailing
        trailing = +""
        # Whitespace inside emphasis isn't allowed: it moves out of the marks.
        if node&.text? && marks.any? { |mark| mark_spec(mark)[:expel_enclosing_whitespace] && !active.include?(mark) }
          lead = node.text[SPACES_START]
          rest = node.text[lead.length..]
          unless lead.empty?
            leading += lead
            node = rest.empty? ? nil : node.with(text: rest)
            marks = active unless node
          end
        end
        if node&.text? && marks.any? { |mark| mark_spec(mark)[:expel_enclosing_whitespace] && !mark_ahead?(parent, index + 1, mark) }
          rest, trail = split_trailing_space(node.text)
          unless trail.empty?
            trailing = trail
            node = rest.empty? ? nil : node.with(text: rest)
            marks = active unless node
          end
        end

        inner = marks.last
        no_escape = inner && mark_spec(inner)[:escape] == false
        length = marks.size - (no_escape ? 1 : 0)
        marks = reorder_mixable(marks, active, length)

        # Close the marks that changed, write the expelled whitespace, then open the new marks.
        keep = 0
        keep += 1 while keep < [active.size, length].min && marks[keep] == active[keep]
        text(mark_string(active.pop, false, parent, index), escape: false) while keep < active.size
        text(leading) unless leading.empty?

        if node
          marks = longest_first(marks, active.size, length, parent, index)
          while active.size < length
            mark = marks[active.size]
            active << mark
            text(mark_string(mark, true, parent, index), escape: false)
            @at_block_start = false
          end

          if no_escape && node.text?
            text(mark_string(inner, true, parent, index) + node.text + mark_string(inner, false, parent, index + 1), escape: false)
          else
            render(node, parent, index)
          end
          @at_block_start = false
        end
        @at_block_start = false if node&.text? && !node.text.empty?
      end
      parent.content.each_with_index { |node, index| progress.call(node, index) }
      progress.call(nil, parent.content.size)
      # Markdown drops spaces at the end of a block too.
      strip_trailing_spaces
      @at_block_start = false
    end

    # Renders a list. `delim` indents the lines of an item after its first, and the block gives the marker
    # of an item's first line from its index. A list is tight when no item holds more than one block, other
    # than nested lists.
    def render_list(node, delim)
      flush_close(1) if @in_tight_list && !(@closed && @closed.type == node.type)

      tight = node.content.all? do |item|
        item.content.count { |child| !@schema.node_type(child.type)&.group&.include?(:list) } <= 1
      end
      previous_tight = @in_tight_list
      @in_tight_list = tight
      node.content.each_with_index do |child, index|
        flush_close(1) if index.positive? && tight
        wrap_block(delim, yield(index), node) { render(child, node, index) }
      end
      @in_tight_list = previous_tight
    end

    # Whether the list follows a list of the same type, which it would continue in Markdown with the same
    # marker. Alternating lists in a row switch markers. The block, called with the siblings before, tells
    # which lists share markers, when other types than the list's do.
    def list_after_list?(parent, index, &same)
      same ||= ->(sibling) { sibling.type == parent.content[index].type }
      run = 0
      run += 1 while index - run - 1 >= 0 && same.call(parent.content[index - run - 1])
      run.odd?
    end

    # The string escaped so that it reads as text in Markdown. At the start of a line, characters that
    # start a block are escaped too. `<` before a tag and `&` before a character reference are escaped, so
    # that they aren't read as HTML.
    def esc(string, start_of_line: false)
      string = string.gsub(/[`*\\~\[\]_]/) do |char|
        index = Regexp.last_match.begin(0)
        # Between letters or digits, `_` can't be emphasis. Not between underscores: `__END__`.
        intraword = char == "_" && index.positive? && index + 1 < string.length &&
          string[index - 1].match?(/[[:alnum:]]/) && string[index + 1].match?(/[[:alnum:]]/)
        intraword ? char : "\\#{char}"
      end
      string = string.gsub(%r{<(?=[A-Za-z/!?])}, "\\<").gsub(/&(?=#?\w+;)/) { "\\&" }
      # URLs and email addresses in text would become links: GitHub Flavored Markdown links them.
      string = string.gsub(%r{\b(https?|ftp)://}i) { "#{Regexp.last_match(1)}\\://" }
        .gsub(/\bwww\./i) { "#{Regexp.last_match(0)[0, 3]}\\." }
        .gsub(/(?<=[\w.+-])@(?=[\w-]+\.\w)/, "\\@")
      if start_of_line
        string = string.sub(/\A(\+ |[-*>])/) { "\\#{Regexp.last_match(1)}" }
          .sub(/\A(\s*)(\#{1,6})(\s|\z)/) { "#{Regexp.last_match(1)}\\#{Regexp.last_match(2)}#{Regexp.last_match(3)}" }
          .sub(/\A(\s*\d+)\.\s/) { "#{Regexp.last_match(1)}\\. " }
      end
      string
    end

    def repeat(string, count)
      string * count
    end

    # The opening or closing syntax of a mark.
    def mark_string(mark, open, parent, index)
      value = mark_spec(mark)[open ? :open : :close]
      value.respond_to?(:call) ? value.call(self, mark, parent, index) : value
    end

    # The mark's syntax: its type's `markdown`, its HTML with `html: true`, or nothing.
    def mark_spec(mark)
      type = @schema.mark_type(mark.type)
      type&.markdown_spec || ((@html && type) ? html_mark(mark, type) : BLANK_MARK)
    end

    # The backticks that open (`side` -1) or close (1) inline code around this node's text: one more than
    # its longest run of backticks, with a space when it has some.
    def backticks_for(node, side)
      length = node&.text? ? node.text.scan(/`+/).map(&:length).max.to_i : 0
      ticks = "`" * (length + 1)
      return ticks if length.zero?

      side.negative? ? "#{ticks} " : " #{ticks}"
    end

    # Whether a link can be written as an autolink, `<https://…>`: its text is its URL, without a title.
    def plain_url?(link, parent, index)
      href = link.attrs[:href].to_s
      return false if link.attrs[:title] || !href.match?(/\A\w+:/)

      content = parent.content[index]
      return false unless content&.text? && content.text == href && content.marks.last == link

      index == parent.content.size - 1 || !parent.content[index + 1].marks.include?(link)
    end

    # A link destination, percent-encoded as Markdown import gives it back, with its parentheses escaped.
    def url(href)
      Markdown::Builder.escape_url(href.to_s).gsub(/[()]/) { "\\#{Regexp.last_match(0)}" }
    end

    # A link title, quoted.
    def title(value)
      value ? %( "#{value.gsub('"', '\\"')}") : ""
    end

    # A node's HTML, for formatting without Markdown syntax.
    def node_html(node)
      Document.new(Node.new(type: @schema.top_node, content: [node]), schema: @schema).to_phlex.call
    end

    private

    def flush_close(size = 2)
      return unless @closed

      @out << "\n" unless at_blank?
      if size > 1
        delim = @delim.sub(/\s+\z/, "")
        (size - 1).times { @out << delim << "\n" }
      end
      @closed = nil
    end

    # Removes the spaces and tabs ending the output after other text. Reads bytes from the end: the output
    # can be long, and a regular expression would scan it all for each block.
    def strip_trailing_spaces
      size = @out.bytesize
      size -= 1 while size.positive? && [32, 9].include?(@out.getbyte(size - 1))
      return if size == @out.bytesize || size.zero? || [10, 13].include?(@out.getbyte(size - 1))

      @out.replace(@out.byteslice(0, size))
    end

    def at_blank?
      @out.empty? || @out.end_with?("\n")
    end

    def hard_break?(node)
      @schema.node_type(node.type)&.linebreak_replacement?
    end

    # Whether the mark continues after `index`, past hard breaks.
    def mark_ahead?(parent, index, mark)
      loop do
        following = parent.content[index]
        return false unless following
        return following.marks.include?(mark) unless hard_break?(following)

        index += 1
      end
    end

    # The marks with the mixable ones about to open sorted by how far they go: the longest opens first,
    # outside the others, so that it doesn't close and reopen when a shorter one ends, like bold around a
    # link and the text after it.
    def longest_first(marks, from, length, parent, index)
      opening = marks[from...length]
      return marks if opening.size < 2 || !opening.all? { |mark| mark_spec(mark)[:mixable] }

      sorted = opening.each_with_index.sort_by { |mark, position| [-run_length(parent, index, mark), position] }.map(&:first)
      marks[0...from] + sorted + marks[length..]
    end

    # How many nodes from `index` on have the mark, without the spaces at the end, which move out of it.
    def run_length(parent, index, mark)
      length = 0
      length += 1 while parent.content[index + length]&.marks&.include?(mark)
      length -= 1 while length > 1 && (node = parent.content[index + length - 1]).text? && node.text.match?(SPACES_ONLY)
      length
    end

    # The parent without the emphasis marks Markdown can't write where they are: as CommonMark's flanking
    # rules require, `**` opens before a non-space, and when it's punctuation, after a space or punctuation,
    # like `Torra**,**`, which can't be bold. Their text stays.
    #
    # When punctuation at an edge of the run is the problem, it moves out of the mark first, as in
    # `l’‘*Association*` for an italic `‘Association`. Each run that can't be written is handled in turn.
    def without_unflanked_marks(parent)
      content = parent.content
      while (run = unflanked_run(content))
        content = fitted(content, *run)
      end
      content.equal?(parent.content) ? parent : parent.with(content: content)
    end

    # The first emphasis mark, with the indexes of its run, that can't be written, or nil.
    def unflanked_run(content)
      content.each_with_index do |node, index|
        node.marks.each do |mark|
          next unless mark_spec(mark)[:expel_enclosing_whitespace]
          next if index.positive? && content[index - 1].marks.include?(mark) # inside a run

          last = index
          last += 1 while content[last + 1]&.marks&.include?(mark)
          return [mark, index, last] unless flanks(content, index, last).all?
        end
      end
      nil
    end

    # The content with the mark's edge punctuation moved out of its run, when that's enough, or else
    # without the mark on the run.
    def fitted(content, mark, first, last)
      opens, closes = flanks(content, first, last)
      trimmed = content.dup
      run_first = first
      run_last = last
      if !closes && (split = split_edge(trimmed[last], mark, /[[:punct:]]+\z/, after: true))
        trimmed[last, 1] = split
      end
      if !opens && (split = split_edge(trimmed[first], mark, /\A[[:punct:]]+/, after: false))
        trimmed[first, 1] = split
        run_first += 1
        run_last += 1
      end
      return trimmed if trimmed.size > content.size && flanks(trimmed, run_first, run_last).all?

      content.each_with_index.map { |node, index| (first..last).cover?(index) ? node.with(marks: node.marks - [mark]) : node }
    end

    # The text node split into its punctuation edge without the mark, and its rest with it, or nil.
    def split_edge(node, mark, pattern, after:)
      return nil unless node.text?

      edge = node.text[pattern]
      return nil if edge.nil? || edge.length == node.text.length

      rest = after ? node.text[0...-edge.length] : node.text[edge.length..]
      outside = node.with(text: edge, marks: node.marks - [mark])
      inside = node.with(text: rest)
      after ? [inside, outside] : [outside, inside]
    end

    # Whether the delimiters around the nodes from `first` to `last` can open and close emphasis, as
    # `[opens, closes]`. The characters around them are the ones written: the backticks of code, the
    # brackets of links.
    def flanks(content, first, last)
      run_marks = content[first].marks
      text = content[first..last].map { |node| written(node, run_marks) }.join
      lead = text[SPACES_START]
      inner, trail = split_trailing_space(text[lead.length..])
      return [true, true] if inner.empty?

      before = lead.empty? ? neighbor_char(content, first, -1, run_marks) : " "
      after = trail.empty? ? neighbor_char(content, last, 1, run_marks) : " "
      [left_flanking?(before, inner[0]), right_flanking?(inner[-1], after)]
    end

    # The written character next to a node, before it (`step` -1) or after it (1), or nil at an edge.
    def neighbor_char(content, index, step, run_marks)
      loop do
        index += step
        return nil if index.negative? || index >= content.size

        text = written(content[index], run_marks)
        return step.negative? ? text[-1] : text[0] unless text.empty?
      end
    end

    # The text without its trailing spaces, and the spaces. Linear: a regular expression for them would
    # backtrack over long texts.
    def split_trailing_space(text)
      last = text.rindex(/[^[:space:]]/)
      last ? [text[0..last], text[(last + 1)..]] : ["", text]
    end

    # A node's text with the syntax of its code and link marks, other than the ones of the run.
    def written(node, run_marks)
      text = node.text? ? node.text : "￼" # an object, like an image: neither space nor punctuation
      node.marks.each do |mark|
        next if run_marks.include?(mark)

        text = "`#{text}`" if mark_spec(mark)[:escape] == false
        text = "[#{text})" if mark_spec(mark).equal?(LINK)
      end
      text
    end

    def left_flanking?(before, following)
      !space?(following) && (!punctuation?(following) || space?(before) || punctuation?(before))
    end

    def right_flanking?(preceding, after)
      !space?(preceding) && (!punctuation?(preceding) || space?(after) || punctuation?(after))
    end

    def space?(char)
      char.nil? || char.match?(/[[:space:]]/)
    end

    def punctuation?(char)
      !char.nil? && char.match?(/[\p{P}\p{S}]/)
    end

    # Marks like bold and italic can open and close in any order: they are put in the order of the open
    # marks, so that fewer of them close and reopen.
    def reorder_mixable(marks, active, length)
      marks = marks.dup
      (0...length).each do |i|
        mark = marks[i]
        break unless mark_spec(mark)[:mixable]

        active.each_with_index do |other, j|
          break unless mark_spec(other)[:mixable]
          next unless mark == other

          if i > j
            marks = marks[0...j] + [mark] + marks[j...i] + marks[(i + 1)...length] + marks[length..]
          elsif j > i
            marks = marks[0...i] + marks[(i + 1)...j] + [mark] + marks[j...length] + marks[length..]
          end
          break
        end
      end
      marks
    end

    # The HTML a mark type renders, split around its content.
    def html_mark(mark, type)
      @html_marks[mark] ||= begin
        component = type.new(**mark.attrs)
        component.instance_variable_set(:@_prosemirror_schema, @schema)
        open, close = component.call { CONTENT }.split(CONTENT, 2)
        {open: open.to_s, close: close.to_s, mixable: true}.freeze
      end
    end
  end
end
