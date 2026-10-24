# Migrating from prosemirror_to_html and html_to_prosemirror

`prosemirror` replaces [`prosemirror_to_html`](https://github.com/etaminstudio/prosemirror_to_html) and [`html_to_prosemirror`](https://github.com/etaminstudio/html_to_prosemirror), which have the same maintainers. Rendering and import use one schema, so a custom type is declared once for both.

```ruby
# Gemfile
gem "prosemirror"
gem "herb" # optional, only if you need HTML import
```

## Rendering, from prosemirror_to_html

```ruby
# Before
ProsemirrorToHtml::Renderer.new.render(json)

# After
Prosemirror.parse(json).to_html
```

`parse` takes the same input: a JSON string, or a Hash with String or Symbol keys. Type names can be in snake_case or camelCase.

### Custom nodes and marks

A node type is a [Phlex](https://www.phlex.fun) component, and its attributes are declared with `prop`. It's registered in a schema instead of a renderer:

```ruby
# Before
class Callout < ProsemirrorToHtml::Nodes::Node
  @node_type = "callout"

  def tag
    [{tag: "aside", attrs: {class: "callout callout-#{@node[:attrs][:tone]}"}}]
  end
end

renderer = ProsemirrorToHtml::Renderer.new.add_node(Callout)
renderer.render(json)

# After
class Callout < Prosemirror::NodeType
  group :block
  content "block+"
  prop :tone, _String?

  def view_template(&) = aside(class: ["callout", @tone && "callout-#{@tone}"], &)
end

schema = Prosemirror::Schema.tiptap.with(Callout)
Prosemirror.parse(json, schema:).to_html
```

| prosemirror_to_html | prosemirror |
|---|---|
| `@node_type = "callout"` | The class name (`Callout` → `callout`), or `type_name :callout` |
| `@tag_name`, `def tag` | `def view_template(&)`, which yields to render the content |
| `@node[:attrs][:tone]` | `prop :tone, _String?`, then `@tone` |
| `def self_closing = true` | No `content`: the node is a leaf |
| `def text` | `view_template` renders whatever the node shows |
| `renderer.add_node(Callout)`, `add_mark` | `Prosemirror::Schema.tiptap.with(Callout)` |
| `renderer.replace_node(Old, New)` | A subclass of the built-in type, registered with `with`, which replaces it |
| `with_nodes([...])`, `with_marks([...])` | `Prosemirror::Schema.new(nodes: [...], marks: [...])` |

Mark types work the same way, with `Prosemirror::MarkType`. See [Node and mark types](TYPES.md) for everything a type can declare.

### Differences in the HTML

prosemirror_to_html built HTML strings, then cleaned them up with Loofah. `prosemirror` builds the HTML with Phlex, which escapes text and attribute values, and cleans nothing up afterwards:

- **Only declared attributes are rendered.** prosemirror_to_html wrote every attribute of a heading, link, image, ordered list or table cell into the HTML, so `{"level": 2, "id": "intro"}` gave `<h2 id="intro">`. `prosemirror` renders the attributes each type declares. To render more, subclass the type (see [Changing built-in types](README.md#changing-built-in-types)). Other attributes are kept in `to_h`.
- **Unsafe URLs are dropped.** A link whose `href` isn't allowed renders as its text, instead of an `<a>` without `href`, and an image without an allowed `src` renders nothing. See [URLs](README.md#urls).
- **Custom types render as written.** Loofah removed elements and attributes it didn't know, like `<iframe>`, `<picture>` or `srcset`. They now render. Pass URLs from the document through `safe_url`.
- **Invalid attributes are fixed and reported** with `on_invalid`, instead of being written as they are. See [Invalid documents](README.md#invalid-documents).
- **HTML5:** strike is `<s>`, not `<strike>`. A code block's language is a `language-` class on `<code>`, and an ordered list starting at 1 has no `start`.
- **Marks are nested in schema order**, as Tiptap nests them, rather than in the order of the JSON: `<strong><em>`.
- **More types:** highlight, task lists, details, mentions, and YouTube and Twitch embeds render, where prosemirror_to_html rendered only their text, or nothing.

## HTML import, from html_to_prosemirror

```ruby
# Before
HtmlToProsemirror::Renderer.new.render(html)                         # snake_case
HtmlToProsemirror::Renderer.new(case_type: :lower_camel).render(html) # camelCase

# After
Prosemirror.from_html(html).to_h
Prosemirror.from_html(html, schema: Prosemirror::Schema.tiptap(case: :camel)).to_h
```

`to_h` returns a Hash with String keys, where html_to_prosemirror returned Symbol keys. HTML import needs the [herb](https://herb-tools.dev) gem.

### Differences in the JSON

The JSON follows the schema, as Tiptap's `generateJSON` does:

- **Documents are valid.** Text in a list item is wrapped in a paragraph, text at the top level too, and attributes have their types: a heading's `level` is `1`, not `"1"`.
- **Nested marks keep their text.** html_to_prosemirror dropped text in nested marks, like `<a><b>bold link</b></a>`.
- **Styles become marks:** `font-weight`, `font-style`, `text-decoration` and `vertical-align`, as in pasted Word or Google Docs content.
- **Whitespace is kept** as HTML defines it: newlines in `<pre>` stay, and character references like `&copy` are decoded.
- **More types:** strike, underline, subscript, superscript, highlight, tables, task lists, details, mentions and embeds.

### The `user` node

html_to_prosemirror turned `<user-mention data-id="7">` into a `user` node. `prosemirror` has Tiptap's `mention` instead. To keep the `user` node, declare it:

```ruby
class User < Prosemirror::NodeType
  group :inline
  inline
  prop :id, _String?, parse_html: ->(element) { element["data-id"] }
  parse_html tag: "user-mention"

  def view_template = span(class: "user-mention", data_id: @id)
end

schema = Prosemirror::Schema.tiptap.with(User)
Prosemirror.from_html(html, schema:).to_h # {"type" => "user", "attrs" => {"id" => "7"}}
```
