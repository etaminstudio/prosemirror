# ProseMirror

Render [ProseMirror](https://prosemirror.net) and [Tiptap](https://tiptap.dev) documents to HTML and text, and import HTML, Markdown and text into them, in Ruby.

- HTML is built with [Phlex](https://www.phlex.fun) and escaped as it is written.
- Attributes are typed with [Literal](https://literal.fun).
- Link and image URLs must use an allowed scheme.
- No Rails dependency.

This gem replaces [prosemirror_to_html](https://github.com/etaminstudio/prosemirror_to_html) and [html_to_prosemirror](https://github.com/etaminstudio/html_to_prosemirror), now deprecated: see [Migrating](MIGRATING.md).

## Why

ProseMirror editors store documents as JSON. Ruby apps need to render this JSON to HTML, extract its text, and import old HTML or Markdown content. Before this gem, that was split across several small gems:

| Gem | Does | Limits |
|---|---|---|
| [`prosemirror_to_html`](https://rubygems.org/gems/prosemirror_to_html) | JSON → HTML | Builds HTML strings, then cleans them with Loofah. Deprecated for this gem |
| [`html_to_prosemirror`](https://rubygems.org/gems/html_to_prosemirror) | HTML → JSON | Few node types, regex-based cleanup. Deprecated for this gem |
| [`prose_mirror_ruby`](https://rubygems.org/gems/prose_mirror_ruby) | JSON → Markdown | Needs ActiveSupport, no HTML |
| [`prose_render`](https://github.com/mattbarrry/prose_render) (unreleased) | JSON → HTML | Needs Rails and ViewComponent |

They use different type names (`bullet_list` or `bulletList`, `strong` or `bold`), and none of them uses the same schema for rendering and parsing. Here, one schema renders, imports and exports.

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
doc.to_markdown  # => "## Hello\n\nWorld\n"
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

## Transforming documents

`transform` builds a new document from a block called with each node. The block returns the node to keep, another node, an array of nodes to put in its place, or nil to remove it:

```ruby
doc = doc.transform do |node|
  case node
  in { type: :paragraph } if node.blank? then nil
  in { type: :heading, attrs: { level: 1 } } then node.with(attrs: { level: 2 })
  in { type: :bullet_list } then node.content.flat_map(&:content)  # unwrap the list
  else node
  end
end
```

- Children are transformed first: the block sees a node with its transformed content, and the nodes it returns aren't transformed again.
- Nodes are immutable: `with` returns a copy with some properties changed, like `content`, `attrs`, `marks` or `text`. Attributes the schema doesn't declare are kept.
- `blank?` is true for nodes that show nothing: no text but whitespace, and no leaf nodes but hard breaks.
- Adjacent text nodes with the same marks are joined. When a node's content changed and lacks what its type requires, like the only paragraph of a list item, the required nodes are added and reported with `on_invalid`.

`check` raises `Prosemirror::InvalidDocument` for the first problem with the schema, with its path: an unknown type, an invalid attribute, content that doesn't match a [content expression](TYPES.md#content-expressions), or marks a node doesn't allow. `valid?` returns true or false. Rendering doesn't need a valid document.

```ruby
doc.check  # raises "doc.content[0]: invalid content for blockquote: paragraph text"
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

It reads GitHub Flavored Markdown: tables, strikethrough, autolinks and task lists. Each Markdown node becomes the element commonmarker renders for it, and the schema's parse rules apply as in HTML import, so custom types can match Markdown too: a type that matches `img` also gets Markdown images. For the built-in types, it gives the same JSON as rendering the Markdown to HTML and importing it in Tiptap, except that:

- code blocks lose their final newline, as in prosemirror-markdown;
- a bullet list whose items all have a checkbox (`- [ ] todo`) is a task list. In other lists, which Tiptap's task lists can't hold, checkboxes stay as text at the start of their item: `[ ] ` or `[x] `.

Raw HTML in Markdown goes through HTML import when the herb gem is installed, and stays as text otherwise.

YAML front matter, between `---` lines at the start, is dropped. Footnotes aren't supported yet: `[^1]: Note` reads as a link definition, as in CommonMark. Markdown nested more than 1,000 levels deep raises `Prosemirror::Error`.

## Markdown export

`to_markdown` writes the document as Markdown, with GitHub Flavored Markdown for tables, strikethrough and task lists, like [prosemirror-markdown](https://github.com/ProseMirror/prosemirror-markdown). It needs no gem.

```ruby
doc.to_markdown              # => "## Hello\n\n**World**\n"
doc.to_markdown(html: true)  # underline, highlight, subscript, superscript and mentions as HTML
```

- Text is escaped, so that it reads back as text: `*`, `_`, `[`, a `#` or `-` that would start a block, HTML-like `<b>`, and URLs that GitHub would turn into links.
- Markdown has no syntax for underline, highlight, subscript, superscript, image sizes or mentions: by default, only their text or image is written, like `@Ada` for a mention. With `html: true`, they are written as HTML.
- Emphasis that CommonMark can't write where it is, like bold on a comma between two letters, is dropped and its text kept.
- Tables are written as GFM tables. A cell's paragraphs and line breaks are joined with `<br>`, and its other blocks, like lists, are written as HTML.
- Details are written as `<details>` HTML, as on GitHub, with their content in Markdown.
- YouTube and Twitch embeds are written as links to the video. With `html: true`, they are written as their iframe.
- Empty paragraphs are left out.

Importing the Markdown gives the document back, as far as Markdown can hold it. Custom types write their own Markdown: see [Node and mark types](TYPES.md#markdown-export).

## Text import

```ruby
doc = Prosemirror.from_text("First line\nsecond line\n\nNew paragraph")
```

Blank lines separate paragraphs, and other line breaks become hard breaks. Spaces are kept.

## Schemas

Two schemas are included:

```ruby
# The default: Tiptap's StarterKit, with tables, images, task lists,
# details, YouTube and Twitch embeds, mentions, underline, subscript,
# superscript and highlight
Prosemirror::Schema.tiptap

# prosemirror-schema-basic and prosemirror-schema-list
Prosemirror::Schema.prosemirror
```

Type names are written in snake_case (`bullet_list`). Use `case: :camel` to write camelCase (`bulletList`), as Tiptap does. Both cases are always accepted on input.

```ruby
Prosemirror.schema = Prosemirror::Schema.tiptap(case: :camel)
```

`case:` doesn't change attribute names: editors only read the exact names they declare, and Tiptap mixes styles (`textAlign`, `colwidth`). The built-in types use Tiptap's exact names, and input accepts both cases.

The two schemas differ in more than names:

| | `Schema.tiptap` | `Schema.prosemirror` |
|---|---|---|
| Marks | `bold`, `italic`, `code`, `link`, `strike`, `underline`… | `strong`, `em`, `code`, `link` |
| Ordered list | `start` | `order` |
| Code block | `language` | no attributes |
| Image | block | inline |
| Link | `href`, `target`, `rel`, `class`, `title` | `href`, `title` |

Each accepts the other's names on input (`strong` for `bold`, `order` for `start`), and the types that are the same in both, like paragraphs, headings and lists, are the same classes.

`text_align: true` adds Tiptap's TextAlign extension, configured for headings and paragraphs: a `textAlign` attribute, `left`, `center`, `right` or `justify`, rendered as a `text-align` style. HTML import also reads the old `align` attribute. Markdown has no syntax for it: Markdown export leaves it out. Without the option, `textAlign` is kept in `to_h`, but not rendered.

```ruby
Prosemirror::Schema.tiptap(text_align: true)
```

YouTube and Twitch embeds store the video's URL in `src`, and render an iframe of its embed URL, built from the video's id: other URLs render nothing. HTML import reads Tiptap's markup, and also iframes of embed URLs without it. Twitch only plays embeds on the domain they name, so set it in a subclass, as Tiptap's `parent` option. YouTube's `nocookie` option is a subclass too:

```ruby
class Twitch < Prosemirror::Nodes::Twitch
  def parent = "example.com"
end

class Youtube < Prosemirror::Nodes::Youtube
  def embed_host = "https://www.youtube-nocookie.com"
end

Prosemirror.schema = Prosemirror::Schema.tiptap.with(Twitch, Youtube)
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

A URL that `resolve_url` or `resolve_urls` resolves to nil, like a link to a deleted record, is reported as `Prosemirror::UnresolvedURL`, a subclass of `InvalidDocument` with the `url`, so that error trackers group dead links apart from other problems.

## URLs

Links and images allow `http`, `https`, `mailto`, `tel` and relative URLs. Change the list with `url_schemes:`, or rewrite URLs before they are checked with `resolve_url:`:

```ruby
Prosemirror::Schema.tiptap(
  url_schemes: %w[https],
  resolve_url: ->(url) { url.start_with?("gid://") ? url_for(GlobalID::Locator.locate(url)) : url }
)
```

`resolve_urls:` gets all the URLs of a document at once, before rendering it, and returns a Hash from each URL to its rewritten URL, to look up records in one query (see the [cookbook](COOKBOOK.md#links-to-records-with-globalid)). A URL missing from the Hash, or mapped to nil, is removed and reported, as with `resolve_url`. The URLs are those of the attributes declared with `url: true`, like links' `href` and images' `src`, which `doc.urls` lists. URLs that types build while rendering, like YouTube's embed URLs, are resolved one at a time.

## Design

- Nothing is cleaned up after rendering: Phlex escapes text and attribute values as it writes them, attributes are typed, attribute names never come from the document, and URLs must use an allowed scheme.
- Output is HTML5 only: no `<strike>`, `<font>` or `align=`. Import still reads them.
- Only `phlex` and `literal` are required. [`herb`](https://herb-tools.dev) and [`commonmarker`](https://github.com/gjtorikian/commonmarker) are loaded only by HTML and Markdown import.
- Schemas, content expressions, marks and parse rules work as in [ProseMirror's guide](https://prosemirror.net/docs/guide/#schema), with the same JSON. Methods keep ProseMirror's names in Ruby style (`text_content`, `descendants`, `check`).
- Nodes are immutable values with pattern matching, documents are `Enumerable`, and node types are classes. Each type declares its attributes, its content, its HTML and how to recognize it in HTML, so rendering and import use the same schema.

Out of scope: CSS framework themes (subclass node types instead), a Rails or ViewComponent dependency, editing features (positions, steps, commands, collaboration), and the editor itself.

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
