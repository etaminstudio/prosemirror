# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "prosemirror"

require "minitest/autorun"

module TestHelpers
  FIXTURES = File.expand_path("fixtures", __dir__)

  def doc(*content) = {"type" => "doc", "content" => content}
  def paragraph(*content) = {"type" => "paragraph", "content" => content}
  def text(value, marks = nil) = {"type" => "text", "text" => value, "marks" => marks}.compact

  def render(json, schema: Prosemirror::Schema.tiptap)
    Prosemirror.parse(json, schema: schema).to_html
  end

  # The problems reported while parsing and rendering, as messages.
  def problems(json, **)
    reported = []
    schema = Prosemirror::Schema.tiptap(on_invalid: ->(error) { reported << error.message }, **)
    document = Prosemirror.parse(json, schema: schema)
    document.to_html
    reported
  end
end
