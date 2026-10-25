# frozen_string_literal: true

module Prosemirror
  # How to recognize a node or a mark in HTML, as ProseMirror's ParseRule:
  # https://prosemirror.net/docs/ref/#model.ParseRule
  #
  # - `tag`: a CSS selector the element must match (see HTML::Selector), or
  # - `style`: a CSS property (`"font-style"`), or a property and value (`"font-style=italic"`), for marks;
  # - `attrs`: attributes to give the node or mark;
  # - `get_attrs`: a block called with the element (or the style's value), returning attributes, nil for
  #   the defaults, or false when the rule doesn't match;
  # - `priority` (default 50): rules with a higher priority are tried first;
  # - `consuming` (default true): false lets the following rules match the element too;
  # - `context`: the parents the rule needs, as `"list_item/"` or `"blockquote//"`;
  # - `ignore`: skip the element and its content;
  # - `skip`: skip the element, but parse its content;
  # - `close_parent`: close the current node;
  # - `content_element`: a selector for the descendant holding the content;
  # - `get_content`: a block called with the element and the schema, returning the nodes to use as content;
  # - `preserve_whitespace`: true to keep spaces, `:full` to also keep newlines;
  # - `clear_mark`: for style rules, true to remove the type's marks, or a block called with each mark.
  # @api private
  ParseRule = Data.define(
    :type, :tag, :style, :attrs, :get_attrs, :priority, :consuming, :context, :ignore, :skip,
    :close_parent, :content_element, :get_content, :preserve_whitespace, :clear_mark
  ) do
    def initialize(type:, tag: nil, style: nil, attrs: nil, get_attrs: nil, priority: 50, consuming: true,
      context: nil, ignore: false, skip: false, close_parent: false, content_element: nil, get_content: nil,
      preserve_whitespace: nil, clear_mark: nil)
      raise ArgumentError, "a parse rule needs a tag or a style" if tag.nil? == style.nil?

      HTML::Selector.parse(tag) if tag
      super
    end

    def node?
      type < NodeType
    end

    # The style's property, without the value.
    def style_property
      style&.split("=", 2)&.first
    end

    # Whether a style rule applies to this property and value.
    def style_matches?(property, value)
      name, expected = style.split("=", 2)
      name == property && (expected.nil? || expected == value)
    end
  end
end
