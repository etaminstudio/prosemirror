# frozen_string_literal: true

# Phlex 2.4.1 checks attribute values against Date without loading it. Remove once a release includes the fix:
# https://github.com/yippee-fun/phlex/issues/974
require "date"
require "json"
require "literal"
require "phlex"
require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "html" => "HTML", "html_parser" => "HTMLParser", "html_renderer" => "HTMLRenderer", "json_parser" => "JSONParser"
)
loader.setup

# Render ProseMirror and Tiptap documents.
module Prosemirror
  class Error < StandardError; end

  # Raised in strict mode, and passed to `on_invalid`, when a document doesn't match its schema.
  class InvalidDocument < Error
    attr_reader :path

    def initialize(message, path: nil)
      @path = path
      super(path ? "#{path}: #{message}" : message)
    end
  end

  class << self
    attr_writer :schema

    # The schema used when none is given. Defaults to `Schema.tiptap`.
    def schema
      @schema ||= Schema.tiptap
    end

    # Build a document from ProseMirror JSON, given as a Hash or a String.
    def parse(json, schema: self.schema)
      schema.parse(json)
    end

    # Build a document from HTML, with the schema's parse rules. Needs the `herb` gem.
    def from_html(html, schema: self.schema)
      schema.parse_html(html)
    end
  end
end
