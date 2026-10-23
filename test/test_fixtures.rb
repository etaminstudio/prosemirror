# frozen_string_literal: true

require "test_helper"

# Each fixture holds a Tiptap document, and its expected HTML and text.
class TestFixtures < Minitest::Test
  Dir[File.join(TestHelpers::FIXTURES, "**/*.json")].each do |path|
    name = path.delete_prefix("#{TestHelpers::FIXTURES}/").delete_suffix(".json").tr("/", "_")
    fixture = JSON.parse(File.read(path))

    define_method(:"test_#{name}_html") do
      assert_equal fixture["html"], Prosemirror.parse(fixture["doc"]).to_html
    end

    define_method(:"test_#{name}_text") do
      assert_equal fixture["text"], Prosemirror.parse(fixture["doc"]).to_text
    end

    define_method(:"test_#{name}_is_valid") do
      reported = []
      schema = Prosemirror::Schema.tiptap(on_invalid: ->(error) { reported << error.message })
      Prosemirror.parse(fixture["doc"], schema: schema).to_html

      assert_empty reported
    end
  end
end
