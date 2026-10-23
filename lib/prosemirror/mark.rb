# frozen_string_literal: true

module Prosemirror
  # A mark applied to a node, such as `bold` or `link`. Marks are immutable values.
  #
  #   mark in { type: :link, attrs: { href: } }
  #
  # As for nodes, `unknown_attrs` holds the attributes the mark's type doesn't declare.
  class Mark < Literal::Data
    prop :type, Symbol, &Coerce::SYMBOL
    prop :attrs, _Hash(Symbol, _Any?), default: {}.freeze, &Coerce::FROZEN
    prop :unknown_attrs, _Hash(String, _Any?), default: {}.freeze, &Coerce::FROZEN

    # A copy with some properties changed.
    def with(**changes)
      self.class.new(**to_h, **changes)
    end
  end
end
