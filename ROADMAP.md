# Roadmap

`prosemirror` is a Ruby gem for [ProseMirror](https://prosemirror.net) and [Tiptap](https://tiptap.dev) documents. It renders them to HTML or text, and imports HTML, Markdown or text into them.

Feedback is welcome in the issues.

## Why

ProseMirror editors store documents as JSON. Ruby apps need to render this JSON to HTML, extract its text, and import old HTML or Markdown content. Today, this is split across several small gems:

| Gem | Does | Downloads | Limits |
|---|---|---|---|
| [`prosemirror_to_html`](https://rubygems.org/gems/prosemirror_to_html) | JSON → HTML | 122k | Builds HTML strings, then cleans them with Loofah |
| [`html_to_prosemirror`](https://rubygems.org/gems/html_to_prosemirror) | HTML → JSON | 19k | Few node types, regex-based cleanup |
| [`prose_mirror_ruby`](https://rubygems.org/gems/prose_mirror_ruby) | JSON → Markdown | 78k | Needs ActiveSupport, no HTML |
| [`prose_render`](https://github.com/mattbarrry/prose_render) (unreleased) | JSON → HTML | — | Needs Rails and ViewComponent |

They use different type names (`bullet_list` or `bulletList`, `strong` or `bold`), and none of them uses the same schema for rendering and parsing. `prosemirror` replaces the first two, which have the same maintainers.

## Principles

- [Phlex](https://www.phlex.fun) builds the HTML and escapes text and attribute values. [Literal](https://literal.fun) types the attributes, so a heading level is an integer from 1 to 6. URLs must use an allowed scheme. Attribute names never come from the document. Nothing is cleaned up after rendering.
- Output is HTML5 only: no `<strike>`, `<font>` or `align=`. The importer still reads them.
- Bad data doesn't break the page. For an invalid attribute:
  1. convert it when the meaning is clear (`"2"` becomes `2`);
  2. otherwise, use its default (a heading with `level: "abc"` becomes an `h1`, and keeps its text);
  3. if it has no default, remove what it belongs to: an image without a valid `src`, or a link with an invalid `href` (the text stays).

  An unknown node renders its content. An `on_invalid` hook reports each problem, for example to an error tracker. A strict mode raises errors instead. `to_h` returns the corrected document.
- Only `phlex` and `literal` are required: no Rails, no Nokogiri. [`herb`](https://herb-tools.dev) (HTML) and [`commonmarker`](https://github.com/gjtorikian/commonmarker) (Markdown) are loaded only by the importers.
- Schemas, content expressions, marks and parse rules work as in [ProseMirror's guide](https://prosemirror.net/docs/guide/#schema), with the same JSON format. Methods keep ProseMirror's names in Ruby style (`text_content`, `descendants`, `check`).
- Nodes are immutable values that support pattern matching. Documents are `Enumerable`. Node types are classes.
- Each node type defines its attributes, its allowed content, its HTML output, and how to recognize it in HTML. Rendering and import use the same schema.

## API

```ruby
doc = Prosemirror.parse(record.content)  # Hash or JSON string
doc = Prosemirror.from_html(html)
doc = Prosemirror.from_markdown(markdown)
doc = Prosemirror.from_text(text)

doc.to_html  # => "<h2>Hello</h2><p>World</p>"
doc.to_text  # => "Hello\n\nWorld"
doc.to_h     # for a json/jsonb column

doc.select { |node| node in { type: :heading, attrs: { level: 1 } } }
```

### Custom nodes

A node type is a Phlex component. Its attributes are Literal properties. Its name comes from the class name (`ImageBlock` → `image_block`).

```ruby
class ImageBlock < Prosemirror::NodeType
  group :block

  prop :src, _String?
  prop :alt, _String?

  parse_html tag: "img[data-block]" do |element|
    { src: element["src"], alt: element["alt"] }
  end

  def view_template
    figure { img(src: safe_url(@src), alt: @alt) }
  end
end

schema = Prosemirror::Schema.tiptap.with(ImageBlock)
Prosemirror.parse(json, schema:).to_html
```

To change a built-in type, subclass it:

```ruby
class Heading < Prosemirror::Nodes::Heading
  prop :id, _String?

  def view_template(&)
    tag(:"h#{@level}", id: @id || slugify(node.text_content), class: "heading", &)
  end
end
```

A node can render parts of its content in different places, with `node` and `render_content`:

```ruby
# A quote whose last line, after a line break, is the author
class Blockquote < Prosemirror::Nodes::Blockquote
  def view_template
    inline = node.content.flat_map(&:content)
    split = inline.rindex { |child| child.type == :hard_break }

    figure do
      blockquote { render_content(split ? inline[...split] : inline) }
      figcaption { render_content(inline[(split + 1)..]) } if split
    end
  end
end
```

A `resolve_url` hook can rewrite URLs before they are checked, for example to turn `gid://` references into links:

```ruby
Prosemirror::Schema.tiptap(resolve_url: ->(url) { url.start_with?("gid://") ? url_for(GlobalID::Locator.locate(url)) : url })
```

In Rails, a custom node can render view components with [`phlex-rails`](https://github.com/yippee-fun/phlex-rails).

### Schemas

The gem has two schemas:

```ruby
Prosemirror::Schema.tiptap       # Tiptap's StarterKit and common extensions (default)
Prosemirror::Schema.prosemirror  # ProseMirror's prosemirror-schema-basic and prosemirror-schema-list
```

They differ in more than names:

| | `Schema.tiptap` | `Schema.prosemirror` |
|---|---|---|
| Marks | `bold`, `italic`, `code`, `link`, `strike`, `underline`… | `strong`, `em`, `code`, `link` |
| Ordered list | `start` | `order` |
| Code block | `language` | no attributes |
| Image | block | inline |
| Link | `href`, `target`, `rel`, `class` | `href`, `title` |

- Both use snake_case type names (`bullet_list`, `hard_break`). `case: :camel` outputs camelCase type names (`bulletList`), as Tiptap does.
- `case:` doesn't change attribute names. Editors only read the exact names they declare, and Tiptap mixes styles (`textAlign`, `colwidth`). In Ruby, attributes are snake_case properties. A different JSON name is declared on the property (`prop :text_align, _String?, json: "textAlign"`), and the built-in types use Tiptap's exact names. Input accepts both forms.
- Both accept input in both cases, and with the other schema's names (`strong` for `bold`, `order` for `start`).
- Nodes that are the same in both (paragraph, heading, blockquote…) use the same classes.

## Milestones

### 0.1: Rendering (released)

- `Node`, `Mark` and `Document` values, built from a Hash or a JSON string, with a nesting limit.
- Normalization as in ProseMirror: marks sorted by schema order, adjacent text with the same marks joined, empty text removed.
- Attributes a type doesn't declare kept in `unknown_attrs`: never rendered, and given back by `to_h`.
- `Schema`, `NodeType` and `MarkType`, with the options of ProseMirror's `NodeSpec` and `MarkSpec`: `content`, `group`, `inline`, `marks`, `whitespace`, `leaf_text`, `excludes`, `spanning`. `marks`, `whitespace` and `excludes` are declared, but only take effect with HTML import (0.2) and validation (0.4), as ProseMirror's `fromJSON` doesn't enforce them either.
- `Schema.tiptap`: `doc`, `paragraph`, `text`, `heading`, `blockquote`, `bullet_list`, `ordered_list`, `list_item`, `code_block`, `hard_break`, `horizontal_rule`, `image`, `table`, `table_row`, `table_header`, `table_cell`. Marks: `link`, `bold`, `italic`, `underline`, `strike`, `code`, `subscript`, `superscript`, `highlight`.
- `Schema.prosemirror`: exactly the nodes and marks of `prosemirror-schema-basic` and `prosemirror-schema-list`.
- `to_html`, with one tag for a mark shared by adjacent text (one `<a>` for a link with mixed formatting).
- `to_phlex` to render in Phlex components, and `render doc` in ERB templates and ViewComponents.
- `node` and `render_content` in node types, to render parts of a node's content.
- `to_text`, like Tiptap's `getText`.
- `case: :camel`, name aliases, allowed URL schemes, `resolve_url` (a URL it can't resolve is removed and reported).
- One JSON test fixture per node and mark, for both schemas.
- A [cookbook](COOKBOOK.md).
- Security tests, starting with every issue fixed in `prosemirror_to_html`:
  - unescaped attribute values ([CVE-2025-64501](https://github.com/etaminstudio/prosemirror_to_html/security/advisories/GHSA-52c5-vh7f-26fx));
  - attribute names from the document, like `onmouseover`, and `javascript:` URLs ([GHSA-6gj3-5qf2-wwvv](https://github.com/etaminstudio/prosemirror_to_html/security/advisories/GHSA-6gj3-5qf2-wwvv));
  - a heading `level` like `1><script>`;
  - other URL schemes, hidden schemes (`java\tscript:`), `style` injection, deep nesting.

### 0.2: HTML import (released)

- `Prosemirror.from_html`, built on [Herb](https://herb-tools.dev), which doesn't raise on bad HTML.
- The importer also needs to:
  - decode entities (`&amp;`, `&eacute;`), with the [WHATWG entity list](https://html.spec.whatwg.org/entities.json);
  - keep `<% %>` in content as text;
  - apply unclosed tags (`<strong>` without `</strong>`) to the rest of their parent;
  - walk the tree without recursion, with a depth limit.
- Parse rules like ProseMirror's `ParseRule`: simple CSS selectors, `style` rules, `attrs`, `priority`, `context`, `ignore`, `skip`, `preserve_whitespace`, and more.
- ProseMirror's `DOMParser` behavior: collapse whitespace, wrap loose text in paragraphs, add missing wrappers (an `<li>` outside a list), unwrap unknown elements, ignore `script`, `style` and similar.
- Marks from inline styles (`font-weight: bold`), for content pasted from Google Docs or Word.
- Old HTML mapped to the schema: `<b>` and `<i>` to `bold` and `italic`, `<strike>` to `strike`, `<tt>` to `code`. `<font>` and `<center>` are unwrapped.
- Tests: HTML from Tiptap gives the same JSON as Tiptap.

### 0.3: Markdown and text import

- `Prosemirror.from_markdown`, built from [`commonmarker`](https://github.com/gjtorikian/commonmarker)'s syntax tree, without going through HTML (like `prosemirror-markdown`). commonmarker's parser is written in Rust.
- GitHub Flavored Markdown: tables, strikethrough, autolinks, task lists.
- Custom node types can define their Markdown mapping.
- Raw HTML in Markdown goes through the HTML importer if Herb is installed.
- `Prosemirror.from_text`: blank lines make paragraphs, line breaks make hard breaks.

### 0.4: Working with documents

- Transformations that return a new document: rewrite links, unwrap lists, split paragraphs, remove empty ones.

  ```ruby
  doc.transform do |node|
    case node
    in { type: :bullet_list } then node.content.map { |item| item.content.first }
    in { type: :paragraph } if node.blank? then nil
    else node
    end
  end
  ```
- Validation against the schema (`check`).

### 0.5: Markdown export

- `doc.to_markdown`, like [`prosemirror-markdown`](https://github.com/ProseMirror/prosemirror-markdown). Useful to send content to LLMs.
- Help wanted: it is self-contained and a good first contribution.

### 0.6: More Tiptap node types

- Task lists, text alignment, mentions, details, embeds.

### 1.0

- Stable API, documentation site, benchmarks.
- Migration guides from `prosemirror_to_html` and `html_to_prosemirror`, and final releases of both pointing to `prosemirror`.
- Used in production by [Trek](https://trek.etamin.studio), a Rails CMS that renders Tiptap documents with custom nodes.

## Out of scope

- CSS framework themes: subclass node types instead.
- A Rails or ViewComponent dependency.
- Editing features: positions, steps, commands, collaboration.
- The editor itself.
