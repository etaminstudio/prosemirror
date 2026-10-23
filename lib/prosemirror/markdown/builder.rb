# frozen_string_literal: true

module Prosemirror
  module Markdown
    # Builds the Elements and Texts of HTML import from Markdown, with commonmarker's syntax tree
    # (https://github.com/gjtorikian/commonmarker), so that the schema's parse rules apply to Markdown too.
    # Each Markdown node becomes the element commonmarker renders for it, without going through HTML.
    #
    # - GitHub Flavored Markdown: tables, strikethrough and autolinks. Task list items stay as text (`[ ] `).
    # - Raw HTML can span several Markdown blocks, like `<del>` around a paragraph: with the herb gem, a
    #   document holding raw HTML is rendered to HTML by commonmarker and imported. Without it, raw HTML
    #   stays as text.
    # - Code blocks lose their final newline, as in prosemirror-markdown.
    # - YAML front matter, between `---` lines at the start, is dropped.
    class Builder
      MAX_DEPTH = HTML::Builder::MAX_DEPTH
      EXTENSIONS = {
        strikethrough: true, table: true, autolink: true, tasklist: false, shortcodes: false, header_ids: nil,
        front_matter_delimiter: "---"
      }.freeze
      RENDER_OPTIONS = {extension: EXTENSIONS, render: {unsafe: true, hardbreaks: false, github_pre_lang: false}}.freeze
      TAGS = {
        paragraph: "p", block_quote: "blockquote", item: "li", thematic_break: "hr", table_row: "tr",
        emph: "em", strong: "strong", strikethrough: "s", linebreak: "br"
      }.freeze
      # A table's delimiter row, like `| :-- | --: |`, at the end of its line.
      DELIMITER_ROW = /\|?(?:\s*:?-+:?\s*\|)*\s*:?-+:?\s*\|?\s*\z/
      # The bytes commonmarker escapes in URLs, as comrak's `escape_href`: all but these, and `%` when it
      # doesn't start an escape. `&` and `'` are kept: comrak writes them as HTML references.
      URL_UNSAFE = %r{%(?!\h\h)|[^-_.+!*(),#@?=;:/$~A-Za-z0-9&'%]}n
      # An IPv6 host at the start of a URL, like `http://[::1]`, kept as it is.
      IPV6_HOST = %r{\A[A-Za-z][A-Za-z0-9+.-]*://\[[\h:.]+\]}

      def self.load_commonmarker
        require "commonmarker"
      rescue LoadError
        raise Error, 'Markdown import needs the commonmarker gem: add `gem "commonmarker"` to your Gemfile'
      end

      # A root Element holding the content.
      def call(markdown)
        self.class.load_commonmarker
        markdown = UTF8.string(markdown)
        document = parse(markdown)
        return from_html(document) if raw_html?(document) && HTML::Builder.herb?

        @lines = markdown.lines
        root = HTML::Element.new("#document")
        build(document, root)
        root
      end

      private

      def parse(markdown)
        Commonmarker.parse(markdown, options: {extension: EXTENSIONS})
      rescue Commonmarker::NestingDepthExceededError => error
        raise Error, "Markdown nested too deeply: #{error.message}"
      end

      # Walks the tree without recursion. Each item of the stack is a node, the element to add it to, and
      # the depth of that element. Elements nested deeper than MAX_DEPTH are flattened.
      def build(document, root)
        stack = document.to_a.reverse.map { |node| [node, root, 0] }
        until stack.empty?
          node, target, depth = stack.pop
          element = add(node, target)
          next unless element

          if depth >= MAX_DEPTH
            element = target
          else
            target.append(element)
          end
          node.to_a.reverse_each { |child| stack << [child, element, element.equal?(target) ? depth : depth + 1] }
        end
      end

      # Adds a node to the target. Returns the element to add its children to, when they need adding.
      def add(node, target)
        type = node.type # commonmarker allocates for each call
        if (tag = TAGS[type])
          return HTML::Element.new(tag)
        end

        case type
        when :heading then HTML::Element.new("h#{node.header_level}")
        when :list then list(node)
        when :code_block then code_block(node, target)
        when :table then table(node)
        when :table_cell then table_cell(node)
        when :link then HTML::Element.new("a", {"href" => escape_url(node.url), "title" => presence(node.title)}.compact)
        when :image then image(node, target)
        when :code then text(target, node.string_content, "code")
        when :text then text(target, node.string_content)
        when :softbreak then text(target, "\n")
        when :html_block then text(target.append(HTML::Element.new("p")), node.literal.chomp)
        when :html_inline then text(target, node.literal)
        when :frontmatter then nil
        else HTML::Element.new("span") # Unwrapped by HTML import, like escaped characters (`\*`).
        end
      end

      def list(node)
        return HTML::Element.new("ul") unless node.list_type == :ordered

        HTML::Element.new("ol", (node.list_start == 1) ? {} : {"start" => node.list_start.to_s})
      end

      def code_block(node, target)
        language = node.fence_info.to_s.split.first
        code = HTML::Element.new("code", language ? {"class" => "language-#{language}"} : {})
        code.append(HTML::Text.new(node.string_content.chomp))
        target.append(HTML::Element.new("pre")).append(code)
        nil
      end

      def table(node)
        @alignments = alignments(node)
        @row = 0
        HTML::Element.new("table")
      end

      # The first row holds header cells.
      def table_cell(node)
        index = cell_index(node)
        @row += 1 if index.zero?
        align = @alignments[index]
        HTML::Element.new((@row == 1) ? "th" : "td", align ? {"style" => "text-align: #{align}"} : {})
      end

      def cell_index(node)
        index = 0
        index += 1 while (node = node.previous_sibling)
        index
      end

      # commonmarker doesn't give the alignments of a table's columns: they are read from its delimiter row,
      # the line after its first line.
      def alignments(node)
        row = @lines[node.source_position[:start_line]].to_s.chomp[DELIMITER_ROW].to_s
        row.strip.delete_prefix("|").delete_suffix("|").split("|").map do |cell|
          cell = cell.strip
          if cell.start_with?(":") && cell.end_with?(":") then "center"
          elsif cell.end_with?(":") then "right"
          elsif cell.start_with?(":") then "left"
          end
        end
      end

      def image(node, target)
        attributes = {"src" => escape_url(node.url), "alt" => plain_text(node), "title" => presence(node.title)}.compact
        target.append(HTML::Element.new("img", attributes))
        nil
      end

      def text(target, value, tag = nil)
        target = target.append(HTML::Element.new(tag)) if tag
        target.append(HTML::Text.new(value))
        nil
      end

      def raw_html?(document)
        document.walk do |node|
          type = node.type
          return true if type == :html_block || type == :html_inline
        end
        false
      end

      def from_html(document)
        root = HTML::Builder.new.call(document.to_html(options: RENDER_OPTIONS, plugins: {syntax_highlighter: nil}))
        chomp_code_blocks(root)
        root
      end

      # The code blocks commonmarker renders, `<pre><code>`, not the `<pre>` elements of raw HTML.
      def chomp_code_blocks(element)
        element.children.each do |child|
          next unless child.element?
          next chomp_code_blocks(child) unless child.name == "pre"

          code = child.children.first
          next unless code&.element? && code.name == "code" && child.children.size == 1

          last = code.children.last
          code.children[-1] = HTML::Text.new(last.value.chomp).tap { |text| text.parent = code } if last.is_a?(HTML::Text)
        end
      end

      # The URL as commonmarker renders it, with the characters URLs can't hold percent-encoded.
      def escape_url(url)
        host = url[IPV6_HOST].to_s
        rest = url.delete_prefix(host).b.gsub(URL_UNSAFE) { |byte| byte.ord.zero? ? "%EF%BF%BD" : format("%%%02X", byte.ord) }
        host + rest.force_encoding(Encoding::UTF_8)
      end

      def plain_text(node)
        node.to_a.map { |child| %i[text code].include?(child.type) ? child.string_content : plain_text(child) }.join
      end

      def presence(value)
        value unless value.nil? || value.empty?
      end
    end
  end
end
