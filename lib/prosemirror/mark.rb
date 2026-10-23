# frozen_string_literal: true

module Prosemirror
  # A mark applied to a node, such as `bold` or `link`. Marks are immutable values.
  #
  #   mark in { type: :link, attrs: { href: } }
  #
  # As for nodes, `unknown_attrs` holds the attributes the mark's type doesn't declare.
  class Mark < Literal::Data
    prop :type, Symbol
    prop :attrs, _Hash(Symbol, _Any?), default: Node::EMPTY_HASH
    prop :unknown_attrs, _Hash(String, _Any?), default: Node::EMPTY_HASH

    # As Node#initialize.
    def initialize(type:, attrs: Node::EMPTY_HASH, unknown_attrs: Node::EMPTY_HASH)
      super(type: type.is_a?(String) ? type.to_sym : type, attrs: Coerce.frozen(attrs), unknown_attrs: Coerce.frozen(unknown_attrs))
    end

    # A copy with some properties changed.
    def with(**changes)
      self.class.new(**to_h, **changes)
    end
  end
end
