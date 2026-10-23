# frozen_string_literal: true

module Prosemirror
  # Class-level declarations shared by node types and mark types.
  module TypeDefinition
    # The name of the type, as a snake_case Symbol. It defaults to the class name (`BulletList` → `:bullet_list`),
    # and subclasses of a concrete type keep its name.
    def type_name(name = nil)
      return @type_name = Naming.snake(name).to_sym if name

      @type_name ||= concrete_superclass&.type_name || derived_type_name
    end

    # Other names accepted on input for this type, such as `:strong` for `:bold`.
    def aliases(*names)
      return @aliases = names.map { |n| Naming.snake(n).to_sym } unless names.empty?

      inherited_setting(:@aliases, [])
    end

    # Declare an attribute. Same as Literal's `prop`, with two options:
    # - `json:` the attribute name in JSON, when it differs from the property name (`"textAlign"`);
    # - `aliases:` other JSON names accepted on input (`["order"]`).
    def prop(name, type, kind = :keyword, json: nil, aliases: [], **, &)
      attribute_names[name] = {json: (json || name).to_s, aliases: aliases.map(&:to_s)}.freeze
      super(name, type, kind, **, &)
    end

    def attribute_names
      @attribute_names ||= concrete_superclass ? concrete_superclass.attribute_names.dup : {}
    end

    # Build valid attributes from JSON attributes (a Hash with String or Symbol keys).
    # Invalid values are converted when the meaning is clear, or replaced by their default.
    # Returns nil when a required attribute is missing or invalid.
    def build_attrs(given, report:)
      given = given.is_a?(Hash) ? given.transform_keys(&:to_s) : {}

      literal_properties.each_with_object({}) do |property, attrs|
        json_name = attribute_names.dig(property.name, :json)
        key = attribute_key(given, attribute_names.fetch(property.name))

        if key
          value = coerce_attribute(property, given[key])
          next attrs[property.name] = value if property.type === value

          report.call("invalid attribute #{json_name}: #{given[key].inspect}")
        elsif !optional_attribute?(property)
          report.call("missing attribute #{json_name}")
        end
        return nil unless optional_attribute?(property)

        attrs[property.name] = default_attribute(property)
      end
    end

    # The JSON attributes this type doesn't declare, with String keys, so that `to_h` gives them back.
    def unknown_attrs(given)
      return {} unless given.is_a?(Hash)

      known = attribute_names.values.flat_map do |names|
        [names[:json], *names[:aliases]].flat_map { |name| [name, Naming.snake(name), Naming.camel(name)] }
      end
      given.transform_keys(&:to_s).except(*known)
    end

    # Attributes as JSON, with their JSON names.
    def serialize_attrs(attrs)
      attrs.to_h { |name, value| [attribute_names.dig(name, :json) || name.to_s, value] }
    end

    def base_type?
      false
    end

    private

    def concrete_superclass
      superclass unless superclass.base_type?
    end

    def derived_type_name
      raise ArgumentError, "anonymous types need a type_name" if name.nil?

      Naming.snake(name.split("::").last).to_sym
    end

    def inherited_setting(ivar, default)
      return instance_variable_get(ivar) if instance_variable_defined?(ivar)
      return default if superclass.base_type?

      superclass.send(:inherited_setting, ivar, default)
    end

    def attribute_key(given, names)
      [names[:json], *names[:aliases]].each do |name|
        [name, Naming.snake(name), Naming.camel(name)].each do |candidate|
          return candidate if given.key?(candidate)
        end
      end
      nil
    end

    def coerce_attribute(property, value)
      property.coercion ? property.coerce(value, context: self) : value
    rescue
      value
    end

    def optional_attribute?(property)
      # Checks whether the Literal type accepts nil, so `.nil?` would be wrong here.
      property.default? || property.type === nil # standard:disable Style/NilComparison
    end

    def default_attribute(property)
      property.default? ? property.default_value(self) : nil
    end
  end
end
