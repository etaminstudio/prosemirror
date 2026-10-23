# frozen_string_literal: true

module Prosemirror
  # Converts names between snake_case (`bullet_list`) and camelCase (`bulletList`).
  module Naming
    module_function

    def snake(name)
      name.to_s.gsub(/([a-z\d])([A-Z])/, '\1_\2').tr("-", "_").downcase
    end

    def camel(name)
      snake(name).gsub(/_([a-z\d])/) { Regexp.last_match(1).upcase }
    end
  end
end
