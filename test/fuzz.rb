# frozen_string_literal: true

# Imports random HTML and Markdown, made by mutating the fixtures' HTML and Markdown, and reports inputs that
# break one of these rules:
#
# - import raises nothing, except TooDeep;
# - the document it gives passes `check`;
# - rendering it and importing it again gives a document that a second round leaves unchanged. With STRICT=1,
#   the first round gives the same document.
#
# Failures are grouped by kind, like the first difference of a round trip, and each kind is shrunk to a small
# input that still fails the same way. Run with `rake fuzz`, for SECONDS (60 by default), with a SEED to
# repeat a run.

require "prosemirror"
require "timeout"

$stdout.sync = true

module Fuzz
  FIXTURES = File.expand_path("fixtures", __dir__)

  # Tags, Word's conditional comments, entities, control characters and Markdown syntax.
  TOKENS = [
    "<", ">", "</", "/>", "&", "&amp;", "&#x;", "&#0;", "&nbsp;", "\"", "'", "=",
    "<p>", "</p>", "<div>", "</div>", "<span>", "<b>", "</b>", "<a href=x>", "</a>", "<img src=x>", "<br>",
    "<ul>", "<ol>", "<li>", "</li>", "<table>", "<tr>", "<td>", "<th>", "</td>", "<pre>", "<code>",
    "<h1>", "<blockquote>", "<details>", "<summary>", "<script>", "<style>", "<iframe src=x>",
    "<!--", "-->", "<![CDATA[", "<!--[if gte mso 9]>", "<![endif]-->", "<?xml?>", "<!DOCTYPE html>",
    "\u0000", " ", " ", "﻿", "é", "🎉", "\r", "\t",
    "**", "_", "`", "```", "> ", "- ", "* ", "1. ", "[", "]", "(", ")", "![", "|", "---", "\n", "\n\n",
    "# ", "~~", "[x] ", "    ", "\\", "<https://x>"
  ].freeze

  TIMEOUT = 5
  STRICT = ENV["STRICT"] == "1"

  module_function

  def run(seconds:, seed:)
    random = Random.new(seed)
    inputs = seeds
    failures = {}
    runs = 0
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds

    while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      format = inputs.keys.sample(random:)
      input = mutate(inputs[format].sample(random:), random)
      runs += 1
      failure = failure(format, input)
      next unless failure

      found = failures[[format, failure]] ||= {count: 0, input:}
      found[:count] += 1
      found[:input] = input if input.length < found[:input].length
    end

    puts "#{runs} inputs in #{seconds} s, seed #{seed}: #{failures.empty? ? "no failures" : "#{failures.size} kinds of failures"}"
    failures.each do |(format, failure), found|
      puts "\n#{format}, #{found[:count]} times: #{failure}"
      puts "  #{shrink(format, failure, found[:input]).inspect}"
    end
    failures.empty?
  end

  def seeds
    fixtures = Dir[File.join(FIXTURES, "**/*.json")].map { |path| JSON.parse(File.read(path)) }.grep(Hash)
    {html: fixtures.filter_map { |fixture| fixture["html"] }, markdown: fixtures.filter_map { |fixture| fixture["markdown"] }}
  end

  def mutate(input, random)
    input = input.dup
    random.rand(1..6).times do
      index = random.rand(input.length + 1)
      case random.rand(5)
      when 0 then input.insert(index, TOKENS.sample(random:))
      when 1 then input[index, random.rand(1..20)] = ""
      when 2 then input.insert(index, input[random.rand(input.length + 1), random.rand(1..40)].to_s)
      when 3 then input.insert(index, TOKENS.sample(random:) * random.rand(2..60))
      when 4 then input.insert(index, input.chars.sample(random.rand(1..5), random:).join)
      end
    end
    input
  end

  # What's wrong with importing the input, or nil.
  def failure(format, input)
    doc = Timeout.timeout(TIMEOUT) { import(format, input) }
    doc.check
    once = Prosemirror.from_html(doc.to_html)
    return "HTML round trip changes #{difference(doc.to_h, once.to_h)}" if STRICT && once != doc

    twice = Prosemirror.from_html(once.to_html)
    "HTML round trip unstable, #{difference(once.to_h, twice.to_h)}" unless twice == once
  rescue Prosemirror::TooDeep
    nil
  rescue Timeout::Error
    "slower than #{TIMEOUT} s"
  rescue => error
    "#{error.class}: #{error.message.lines.first.to_s.strip[0, 120]}"
  end

  # Where two documents first differ: the node type and what differs in it, like "table_header colwidth".
  def difference(before, after)
    return "#{before["type"]} text" if before["text"] != after["text"]
    return "#{before["type"]} type, #{after["type"]} instead" if before["type"] != after["type"]

    attrs = (before["attrs"] || {}).merge(after["attrs"] || {}).keys.find { |name| before.dig("attrs", name) != after.dig("attrs", name) }
    return "#{before["type"]} #{attrs}" if attrs
    return "#{before["type"]} marks" if before["marks"] != after["marks"]

    children = [before["content"] || [], after["content"] || []]
    index = children.map(&:size).max.times.find { |i| children[0][i] != children[1][i] }
    return "#{before["type"]} content" if index.nil? || children.any? { |nodes| nodes[index].nil? } || children[0][index]["type"] != children[1][index]["type"] && children[0].size != children[1].size

    difference(children[0][index], children[1][index])
  end

  def import(format, input)
    (format == :html) ? Prosemirror.from_html(input) : Prosemirror.from_markdown(input)
  end

  # Removes chunks of characters, halving their size down to one, while the input fails the same way.
  def shrink(format, failure, input)
    size = input.length / 2
    while size >= 1
      index = 0
      while index < input.length
        candidate = input[0, index] + input[(index + size)..].to_s
        if failure(format, candidate) == failure
          input = candidate
        else
          index += size
        end
      end
      size = (size == 1) ? 0 : size / 2
    end
    input
  end
end

exit Fuzz.run(seconds: Float(ENV.fetch("SECONDS", 60)), seed: Integer(ENV.fetch("SEED", Random.new_seed % 1_000_000)))
