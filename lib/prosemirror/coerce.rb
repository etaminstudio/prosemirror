# frozen_string_literal: true

module Prosemirror
  # Conversions for property values, used as Literal coercion blocks:
  #
  #   prop :level, _Integer(1..6), default: 1, &Coerce::INTEGER
  module Coerce
    # "2" becomes 2.
    INTEGER = proc { |value| (value.is_a?(String) && value.match?(/\A\s*-?\d+\s*\z/)) ? value.to_i : value }

    # "bullet_list" becomes :bullet_list.
    SYMBOL = proc { |value| value.is_a?(String) ? value.to_sym : value }

    # A frozen copy, unless the value is already frozen.
    FROZEN = proc { |value| value.frozen? ? value : value.dup.freeze }
  end
end
