# ProseMirror

Render [ProseMirror](https://prosemirror.net) and [Tiptap](https://tiptap.dev) documents to HTML and text, and import HTML, Markdown and text into them, in Ruby.

- HTML is built with [Phlex](https://www.phlex.fun) and escaped as it is written.
- Attributes are typed with [Literal](https://literal.fun).
- Link and image URLs must use an allowed scheme.
- No Rails dependency.

This gem replaces [prosemirror_to_html](https://github.com/etaminstudio/prosemirror_to_html) and [html_to_prosemirror](https://github.com/etaminstudio/html_to_prosemirror). See the [roadmap](ROADMAP.md) for what comes next.

## Installation

```sh
bundle add prosemirror
```

## Usage

```ruby
require "prosemirror"

doc = Prosemirror.parse(record.content)  # a Hash or a JSON string

doc.to_html  # => "<h2>Hello</h2><p>World</p>"
doc.to_text  # => "Hello\n\nWorld"
doc.to_h     # => { "type" => "doc", "content" => [...] }
```

`to_h` gives the document back as JSON, with invalid parts fixed (see [Invalid documents](#invalid-documents)). Attributes the schema doesn't declare, for example from a Tiptap extension it doesn't know, are kept as they are in `unknown_attrs`, and never rendered.

In Rails, `to_html` returns an `html_safe` string, and documents can be rendered like other objects in ERB templates and ViewComponents:

```erb
<%= render doc %>
```

In a Phlex component, use `to_phlex`, which writes directly into the page:

```ruby
render doc.to_phlex
```

Documents are `Enumerable`, and nodes support pattern matching:

```ruby
doc.select { |node| node in { type: :heading, attrs: { level: 1 } } }
doc.content.first.text_content
```

## HTML import

HTML import uses [Herb](https://herb-tools.dev)'s parser, which never raises on malformed HTML. Add it to your Gemfile:

```sh
bundle add herb
```

```ruby
doc = Prosemirror.from_html("<h2>Hello</h2><p>World</p>")
doc.to_h  # => { "type" => "doc", "content" => [{ "type" => "heading", ... }, ...] }
```

It works like ProseMirror's `DOMParser`, and for the built-in types gives the same JSON as Tiptap's `generateJSON`, apart from invalid attributes:

- each node and mark type recognizes its elements with its parse rules: `<b>`, `<strong>` and `font-weight: bold` all give `bold`;
- whitespace is collapsed, except in code blocks;
- content that doesn't fit where it is gets wrapped or moved: loose text becomes a paragraph, an `<li>` outside a list gets a list;
- elements without a rule are unwrapped, and `script`, `style` and similar are ignored;
- entities are decoded, and ERB tags (`<%= … %>`) are kept as text;
- invalid attributes are fixed and reported, as in [Invalid documents](#invalid-documents).

## Markdown import

Markdown import uses [commonmarker](https://github.com/gjtorikian/commonmarker)'s parser, written in Rust. Add it to your Gemfile:

```sh
bundle add commonmarker
```

```ruby
doc = Prosemirror.from_markdown("## Hello\n\nSome **bold** text.")
```

It reads GitHub Flavored Markdown: tables, strikethrough and autolinks. Each Markdown node becomes the element commonmarker renders for it, and the schema's parse rules apply as in HTML import, so custom types can match Markdown too: a type that matches `img` also gets Markdown images. For the built-in types, it gives the same JSON as rendering the Markdown to HTML and importing it in Tiptap, except that:

- code blocks lose their final newline, as in prosemirror-markdown;
- task list items (`- [ ] todo`) stay as list items starting with `[ ] ` or `[x] `.

Raw HTML in Markdown goes through HTML import when the herb gem is installed, and stays as text otherwise.

YAML front matter, between `---` lines at the start, is dropped. Footnotes aren't supported yet: `[^1]: Note` reads as a link definition, as in CommonMark. Markdown nested more than 1,000 levels deep raises `Prosemirror::Error`.

## Text import

```ruby
doc = Prosemirror.from_text("First line\nsecond line\n\nNew paragraph")
```

Blank lines separate paragraphs, and other line breaks become hard breaks. Spaces are kept.

## Schemas

Two schemas are included:

```ruby
Prosemirror::Schema.tiptap       # Tiptap's StarterKit, tables, images, underline, subscript, superscript, highlight (default)
Prosemirror::Schema.prosemirror  # prosemirror-schema-basic and prosemirror-schema-list
```

Type names are written in snake_case (`bullet_list`). Use `case: :camel` to write camelCase (`bulletList`), as Tiptap does. Both cases are always accepted on input.

```ruby
Prosemirror.schema = Prosemirror::Schema.tiptap(case: :camel)
```

## Custom nodes and marks

A node type is a Phlex component, and its attributes are Literal properties. The type name comes from the class name (`ImageBlock` → `image_block`).

```ruby
class ImageBlock < Prosemirror::NodeType
  group :block

  prop :src, String
  prop :caption, _String?

  def view_template
    figure do
      img(src: safe_url(@src))
      figcaption { @caption } if @caption
    end
  end
end

Prosemirror.schema = Prosemirror::Schema.tiptap.with(ImageBlock)
```

In `view_template`, `node` is the node being rendered, and `render_content(nodes)` renders any of its descendants.

`parse_html` says which elements become this type when importing HTML, and `prop … parse_html:` how to read an attribute:

```ruby
class ImageBlock < Prosemirror::NodeType
  prop :caption, _String?, parse_html: ->(element) { element.query("figcaption")&.text_content }

  parse_html(tag: "figure.image") { |element| {src: element.query("img")&.[]("src")} }
end
```

[Node and mark types](TYPES.md) documents every option: groups, content expressions, allowed marks, attribute names in JSON, rendering helpers, and parse rules. See the [cookbook](COOKBOOK.md) for recipes, like skipping empty paragraphs.

### Changing built-in types

To change how a built-in type renders, subclass it:

```ruby
class Paragraph < Prosemirror::Nodes::Paragraph
  def view_template(&) = p(class: "text-lg", &)
end

Prosemirror.schema = Prosemirror::Schema.tiptap.with(Paragraph)
```

## Invalid documents

Bad data doesn't break the page. For an invalid attribute, the gem:

1. converts it when the meaning is clear (`"2"` becomes `2`);
2. otherwise, uses its default;
3. if it has no default, removes the node or mark (a link with an invalid `href` keeps its text).

Unknown nodes render their content. Report problems, or raise them:

```ruby
Prosemirror::Schema.tiptap(on_invalid: ->(error) { Rails.error.report(error) })
Prosemirror::Schema.tiptap(strict: true)  # raises Prosemirror::InvalidDocument
```

## URLs

Links and images allow `http`, `https`, `mailto`, `tel` and relative URLs. Change the list with `url_schemes:`, or rewrite URLs before they are checked with `resolve_url:`:

```ruby
Prosemirror::Schema.tiptap(
  url_schemes: %w[https],
  resolve_url: ->(url) { url.start_with?("gid://") ? url_for(GlobalID::Locator.locate(url)) : url }
)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests, and `rake` to also run [Standard](https://github.com/standardrb/standard). You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

To release a new version, update the version number in `version.rb` and the changelog, and merge them into main. Then tag the version and push the tag:

```sh
git tag v0.3.0 && git push origin v0.3.0
```

The [Push gem](.github/workflows/push_gem.yml) workflow publishes the gem to [rubygems.org](https://rubygems.org) with [trusted publishing](https://guides.rubygems.org/trusted-publishing/), after approval in the `release` environment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/etaminstudio/prosemirror.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
