# frozen_string_literal: true

# Measures prosemirror on a page and on a long document, and compares rendering and HTML import with the
# gems it replaces. Run from the repository root:
#
#   BUNDLE_GEMFILE=benchmark/Gemfile bundle install
#   BUNDLE_GEMFILE=benchmark/Gemfile bundle exec ruby benchmark/run.rb
#
# It ends with a Markdown table of the times, for the README. Set TIME (seconds per operation, default 2)
# to trade precision for speed, and NO_YJIT=1 to measure without YJIT, which Rails enables by default.
require "benchmark/ips"
require "json"
require "prosemirror"
require "prosemirror_to_html"
require "html_to_prosemirror"
require_relative "documents"

RubyVM::YJIT.enable if defined?(RubyVM::YJIT) && !ENV["NO_YJIT"]
TIME = Float(ENV.fetch("TIME", "2"))

schema = Prosemirror::Schema.tiptap(case: :camel)
legacy_renderer = ProsemirrorToHtml::Renderer.new
legacy_importer = HtmlToProsemirror::Renderer.new
documents = {"Page" => Documents.page, "Long document" => Documents.long}
times = Hash.new { |hash, key| hash[key] = {} }

# Runs the operations, and keeps the time each one takes, in milliseconds.
measure = lambda do |document_name, operations, compare: false|
  report = Benchmark.ips do |x|
    x.config(time: TIME, warmup: 1)
    operations.each { |name, block| x.report(name, &block) }
    x.compare! if compare
  end
  report.entries.each { |entry| times[entry.label][document_name] = 1000.0 / entry.ips }
end

yjit = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
puts "Ruby #{RUBY_VERSION}, YJIT #{yjit ? "on" : "off"}, prosemirror #{Prosemirror::VERSION}"
sizes = documents.map do |name, json|
  document = schema.parse(json)
  string = JSON.generate(json)
  html = document.to_html
  markdown = document.to_markdown
  text = document.to_text
  puts "\n## #{name}: #{document.count} nodes"

  measure.call(name, {
    "parse JSON" => -> { schema.parse(string) },
    "to_html" => -> { document.to_html },
    "to_text" => -> { document.to_text },
    "to_markdown" => -> { document.to_markdown },
    "to_h" => -> { document.to_h },
    "from_html" => -> { schema.from_html(html) },
    "from_markdown" => -> { schema.from_markdown(markdown) },
    "from_text" => -> { schema.from_text(text) },
    "transform" => -> { document.transform { |node| node } },
    "check" => -> { document.check }
  })
  measure.call(name, {
    "JSON to HTML" => -> { schema.parse(string).to_html },
    "JSON to HTML, prosemirror_to_html" => -> { legacy_renderer.render(string) }
  }, compare: true)
  measure.call(name, {
    "HTML to JSON" => -> { schema.from_html(html).to_h },
    "HTML to JSON, html_to_prosemirror" => -> { legacy_importer.render(html.dup) }
  }, compare: true)

  "#{name}: #{document.count} nodes, #{string.bytesize / 1024} KB of JSON"
end

format_time = ->(ms) { (ms < 1) ? format("%.2f ms", ms) : format("%.1f ms", ms) }
puts "\n#{sizes.join(", ")}.\n\n| | #{documents.keys.join(" | ")} |\n|---|#{"--:|" * documents.size}"
times.each { |label, by_document| puts "| #{label} | #{documents.keys.map { |name| format_time.call(by_document[name]) }.join(" | ")} |" }
