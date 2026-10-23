# frozen_string_literal: true

require "test_helper"

# Each fixture holds a document, and its expected HTML and text. Fixtures in `prosemirror/` use
# `Schema.prosemirror`, the others `Schema.tiptap`.
class TestFixtures < Minitest::Test
  Dir[File.join(TestHelpers::FIXTURES, "**/*.json")].each do |path|
    name = path.delete_prefix("#{TestHelpers::FIXTURES}/").delete_suffix(".json").tr("/", "_")
    fixture = JSON.parse(File.read(path))
    schema = name.start_with?("prosemirror_") ? :prosemirror : :tiptap

    define_method(:"test_#{name}_html") do
      assert_equal fixture["html"], Prosemirror.parse(fixture["doc"], schema: Prosemirror::Schema.public_send(schema)).to_html
    end

    define_method(:"test_#{name}_text") do
      assert_equal fixture["text"], Prosemirror.parse(fixture["doc"], schema: Prosemirror::Schema.public_send(schema)).to_text
    end

    define_method(:"test_#{name}_is_valid") do
      reported = []
      reporting = Prosemirror::Schema.public_send(schema, on_invalid: ->(error) { reported << error.message })
      Prosemirror.parse(fixture["doc"], schema: reporting).to_html

      assert_empty reported
    end
  end
end
