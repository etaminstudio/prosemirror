# frozen_string_literal: true

module Prosemirror
  module HTML
    # Builds Elements and Texts from HTML, with Herb's parser (https://herb-tools.dev), which never raises
    # on malformed HTML. It also does what Herb leaves to its users:
    # - decodes character references, in text and attribute values;
    # - keeps ERB tags (`<% %>`) as text;
    # - applies an opening tag without a closing tag to the rest of its parent, as browsers do;
    # - drops comments (including Word's `<![if …]>`), doctypes and CDATA;
    # - walks the tree without recursion, and flattens elements nested deeper than MAX_DEPTH.
    class Builder
      MAX_DEPTH = 256
      # The size of the pieces Herb parses, in bytes. See Splitter.
      PIECE_SIZE = 65_536
      # What browsers read as a comment, and Herb leaves in text, like Word's `<![if !supportLists]>`.
      BOGUS_COMMENT = /<![^>]*>/

      def self.load_herb
        require "herb"
      rescue LoadError
        raise Error, 'HTML import needs the herb gem: add `gem "herb"` to your Gemfile'
      end

      # Whether the herb gem is installed.
      def self.herb?
        load_herb
        true
      rescue Error
        false
      end

      # A root Element holding the parsed content.
      def call(html)
        self.class.load_herb
        root = Element.new("#document")
        Splitter.new(PIECE_SIZE).call(UTF8.string(html)).each do |piece|
          # Without `timeout: 0`, Herb stops after a second and returns what it parsed so far.
          build(Herb.parse(piece, track_locations: false, strict: false, timeout: 0).value.children, root)
        end
        root
      end

      private

      # Each item of the stack is a list of Herb nodes, the position in it, the element to add them to,
      # and its depth.
      def build(nodes, root)
        stack = [[nodes, 0, root, 0]]
        until stack.empty?
          frame = stack.last
          list, index, target, depth = frame
          if index >= list.size
            stack.pop
            next
          end
          frame[1] += 1
          child = add(list[index], target, depth)
          next unless child

          element, children = child
          if element.equal?(target)
            stack << [children, 0, target, depth]
          elsif children.nil? # an opening tag without a closing tag: the rest of the list goes in it
            frame[2] = element
            frame[3] = depth + 1
          else
            stack << [children, 0, element, depth + 1]
          end
        end
      end

      # Adds a Herb node to the target. Returns the element to fill and the Herb nodes to fill it with,
      # when the node has children.
      def add(node, target, depth)
        case node
        when Herb::AST::HTMLElementNode then add_element(node, target, depth)
        when Herb::AST::HTMLOpenTagNode then add_open_tag(node, target, depth)
        when Herb::AST::HTMLTextNode then add_text(Entities.decode(node.content.to_s.gsub(BOGUS_COMMENT, "")), target)
        when Herb::AST::LiteralNode then add_text(node.content.to_s, target)
        when Herb::AST::WhitespaceNode then add_text(node.value&.value.to_s, target)
        when Herb::AST::HTMLCommentNode, Herb::AST::HTMLDoctypeNode, Herb::AST::XMLDeclarationNode,
             Herb::AST::XMLProcessingInstructionNode, Herb::AST::CDATANode, Herb::AST::HTMLCloseTagNode
          nil
        else add_other(node, target)
        end
      end

      def add_element(node, target, depth)
        open_tag = node.open_tag
        return [target, node.body] unless open_tag.respond_to?(:tag_name) && open_tag.tag_name

        element = new_element(open_tag)
        return [target, node.body] if depth >= MAX_DEPTH

        target.append(element)
        [element, node.body]
      end

      def add_open_tag(node, target, depth)
        element = new_element(node)
        return nil if depth >= MAX_DEPTH

        target.append(element)
        node.is_void ? nil : [element, nil]
      end

      # ERB tags become text. Other nodes give their children, if any.
      def add_other(node, target)
        if node.respond_to?(:tag_opening) && node.respond_to?(:content) && node.respond_to?(:tag_closing)
          add_text([node.tag_opening, node.content, node.tag_closing].map { |token| token&.value.to_s }.join, target)
        end
        children = node.respond_to?(:child_nodes) ? node.child_nodes.compact : []
        children.empty? ? nil : [target, children]
      end

      def add_text(value, target)
        return nil if value.empty?

        last = target.children.last
        if last.is_a?(Text)
          target.children[-1] = Text.new(last.value + value).tap { |text| text.parent = target }
        else
          target.append(Text.new(value))
        end
        nil
      end

      def new_element(open_tag)
        Element.new(open_tag.tag_name.value.downcase, attributes(open_tag.children))
      end

      # The first value wins when an attribute is repeated, as in browsers.
      def attributes(nodes)
        nodes.grep(Herb::AST::HTMLAttributeNode).each_with_object({}) do |attribute, result|
          name = text_of(attribute.name&.children).downcase
          next if name.empty? || result.key?(name)

          result[name] = Entities.decode(text_of(attribute.value&.children), attribute: true)
        end
      end

      def text_of(nodes)
        Array(nodes).map do |node|
          if node.respond_to?(:tag_opening) && node.respond_to?(:tag_closing)
            [node.tag_opening, node.content, node.tag_closing].map { |token| token&.value.to_s }.join
          else
            node.content.to_s
          end
        end.join
      end
    end
  end
end
