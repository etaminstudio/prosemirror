# Node and mark types

Each node and mark of a document has a type, a Ruby class. A type declares its name, its attributes, what it can contain, how it renders to HTML, and how to recognize it when importing HTML. The options follow ProseMirror's [NodeSpec](https://prosemirror.net/docs/ref/#model.NodeSpec) and [MarkSpec](https://prosemirror.net/docs/ref/#model.MarkSpec).

```ruby
class Callout < Prosemirror::NodeType
  group :block
  content "paragraph+"

  prop :tone, _String?

  parse_html(tag: "aside.callout") { |element| {tone: element["data-tone"]} }

  def view_template(&) = aside(class: "callout", data_tone: @tone, &)
end

Prosemirror.schema = Prosemirror::Schema.tiptap.with(Callout)
```

A type is a [Phlex](https://www.phlex.fun) component, and its attributes are [Literal](https://literal.fun) properties. `Schema#with` adds a type to a schema, or replaces the type with the same name.

- [Names](#names)
- [Node type options](#node-type-options)
- [Mark type options](#mark-type-options)
- [Content expressions](#content-expressions)
- [Attributes](#attributes)
- [Rendering](#rendering)
- [Parse rules](#parse-rules)
- [Markdown](#markdown)
- [Markdown export](#markdown-export)
- [Subclassing built-in types](#subclassing-built-in-types)

## Names

| Option | Meaning |
|---|---|
| `type_name :image_block` | The type name. Defaults to the class name in snake_case (`ImageBlock` → `image_block`). |
| `aliases :figure, :picture` | Other names accepted on input. `Bold` accepts `strong`. |

Type names are snake_case Symbols in Ruby. On input, camelCase works too (`imageBlock`). The schema's `case:` option chooses how they are written in JSON.

## Node type options

| Option | Default | Meaning |
|---|---|---|
| `group :block, :list` | none | The groups of the type, used in content expressions and in `marks`. |
| `content "inline*"` | none: the node is a leaf | The children allowed, as a [content expression](#content-expressions). |
| `inline` | false | The node is inline, like text. Also implied by `group :inline`. |
| `marks "bold italic"` | all, in nodes with inline content | The marks allowed inside: names or groups separated by spaces, `"_"` for all, `""` for none. |
| `code` | false | The node holds code. Implies `whitespace :pre`. |
| `whitespace :pre` | `:normal` | Keep spaces and newlines when importing HTML. |
| `leaf_text "\n"` | `""` | The text of a leaf node in `to_text`. Also takes a block, called with the node. |
| `linebreak_replacement` | false | When importing HTML that keeps whitespace, newlines become nodes of this inline type, like `hard_break`. |

## Mark type options

| Option | Default | Meaning |
|---|---|---|
| `group :font` | none | The groups of the type, used in `excludes` and in a node's `marks`. |
| `excludes "_"` | marks of the same type | The marks this one can't be combined with: names or groups, `"_"` for all. A link excludes other links, and Tiptap's `code` excludes all marks. |
| `spanning false` | true | Render one element per text node, instead of one for adjacent nodes with the same mark. |
| `code` | false | The mark holds code, as ProseMirror's `code`. Not used by this gem yet. |

The order of marks in the schema sorts the marks of a node, and nests their elements: the first mark is the outermost element.

## Content expressions

`content` says which children a node can have. It works like a regular expression, with node names or group names instead of characters:

| Expression | Meaning |
|---|---|
| `"text*"` | Zero or more text nodes. |
| `"inline*"` | Zero or more nodes of the `inline` group: text, hard breaks… |
| `"block+"` | One or more nodes of the `block` group. |
| `"paragraph block*"` | A paragraph, then zero or more blocks. |
| `"(table_cell \| table_header)*"` | Zero or more cells or header cells. |
| `"caption?"` | Zero or one caption. |
| `"cell{2}"`, `"cell{1,5}"`, `"cell{2,}"` | Exactly two, one to five, two or more cells. |

The built-in types use these groups: `block` for paragraphs, headings, lists, tables…, `inline` for text and hard breaks, and `list` for lists.

HTML import follows content expressions, to wrap content that doesn't fit where it is, or move it up. `to_text` uses them to find the nodes that contain text. Rendering doesn't check them.

## Attributes

Attributes are declared with Literal's `prop`, as keyword properties, and are available as instance variables in `view_template`:

```ruby
prop :level, _Integer(1..6), default: 1, &Prosemirror::Coerce::INTEGER
prop :src, _String(length: 1..)
prop :alt, _String?
```

- **Type:** a Literal type. A value that doesn't match it is invalid (see [Invalid documents](README.md#invalid-documents)).
- **Default:** used when the attribute is missing or invalid. Literal needs a frozen value or a Proc: `default: "left".freeze`, or a file with `# frozen_string_literal: true`. An attribute that accepts nil defaults to nil. An attribute without a default is required: without a valid value, the node or mark is removed.
- **Coercion:** the block converts values before they are checked. `Prosemirror::Coerce::INTEGER` turns `"2"` into `2`.

`prop` takes four more options:

| Option | Meaning |
|---|---|
| `json: "textAlign"` | The name in JSON, when it differs from the property name. |
| `aliases: ["order"]` | Other JSON names accepted on input. |
| `url: true` | The attribute holds a URL: `doc.urls` lists it, and the schema's `resolve_urls` resolves it with the document's other URLs before rendering. Render it with `safe_url`. |
| `parse_html: ->(element) { … }` | How to read the attribute from an HTML element, when importing HTML. By default, the HTML attribute with the JSON name is read. |

Attributes that a type doesn't declare are kept in `unknown_attrs`. They are never rendered, and `to_h` gives them back.

## Rendering

A type renders with `view_template`, which yields to render its content. For a mark, the content is the marked text.

```ruby
def view_template(&) = blockquote(class: "quote", &)
```

Without `view_template`, the content is rendered without a wrapping element. These methods are also available:

| Method | Returns |
|---|---|
| `node` | The node being rendered, a `Prosemirror::Node`. Not available in mark types. |
| `render_content(nodes)` | Renders any list of nodes, with their marks, for example only some of the node's children. |
| `safe_url(url)` | The URL after the schema's `resolve_url`, when its scheme is allowed, or nil. Use it for every URL from the document. |
| `prosemirror_schema` | The schema of the document being rendered. |

Phlex escapes text and attribute values, but doesn't check URLs: pass them through `safe_url`.

## Parse rules

`parse_html` says which elements become this type when importing HTML, like ProseMirror's [parse rules](https://prosemirror.net/docs/ref/#model.ParseRule). A type can have several rules. A type without rules is never created by HTML import.

```ruby
parse_html tag: "h1", attrs: {level: 1}
parse_html(tag: "b") { |element| element.style["font-weight"] != "normal" && {} }
parse_html(style: "font-weight") { |value| value.match?(/bold|[5-9]00/) && {} }
```

The block is called with the element, or with the value of the style for a style rule. It returns the attributes, `nil` for the defaults, or `false` when the rule doesn't match. A block with two parameters also gets the schema: `{ |element, schema| … }`.

The attributes are built from the rule's `attrs` or block, then from the values each `prop` reads from the element. Values read from the element take precedence, as in Tiptap.

| Option | Meaning |
|---|---|
| `tag: "img[src]"` | A CSS selector the element must match. |
| `style: "font-style=italic"` | For mark types: a CSS property, or a property and value. |
| `attrs: {level: 1}` | Attributes to give the node or mark. |
| `priority: 60` | Rules with a higher priority are tried first. Defaults to 50. Rules with the same priority are tried in schema order, mark types first. |
| `consuming: false` | Let the following rules match the element too, for example to apply several marks. |
| `context: "list_item/"` | The parents the rule needs. See below. |
| `ignore: true` | Skip the element and its content. |
| `skip: true` | Skip the element, but parse its content. |
| `close_parent: true` | Close the current node: the content that follows goes after it. |
| `content_element: "figcaption"` | A selector, or a block called with the element, giving the descendant that holds the content. |
| `get_content: ->(element, schema) { … }` | Returns the nodes to use as content, instead of parsing the element's children. |
| `preserve_whitespace: true` | Keep spaces. Newlines become `hard_break` nodes where they fit, and spaces otherwise. With `:full`, newlines stay in the text. |
| `clear_mark: true` | For style rules: remove the marks of this type, as `font-weight: normal` does for bold. Also takes a block called with each mark. |

### Selectors

`tag` takes a list of compound selectors, separated by commas: a type (`p`, `*`), `#id`, `.class`, attribute selectors (`[href]`, `[a=b]`, `[a^=b]`, `[a$=b]`, `[a*=b]`, `[a~=b]`, `[a|=b]`), and `:not(…)`. Combinators like `div > p` aren't supported: use `context`, or check the element in the block.

### Context

`context` matches the nodes the content is being added to, from the innermost one:

| Context | Matches |
|---|---|
| `"list_item/"` | Directly in a list item. |
| `"blockquote//"` | Anywhere inside a blockquote. |
| `"list_item/paragraph/"` | In a paragraph directly in a list item. |
| `"blockquote/ \| list_item/"` | One of several contexts. |

Group names work too.

### Elements

The element passed to rules is a `Prosemirror::HTML::Element`, with lowercase names, and attribute values with their character references decoded:

| Method | Returns |
|---|---|
| `name` | The tag name, like `"img"`. |
| `element["src"]` | An attribute value, or nil. |
| `key?("data-id")` | Whether the attribute is present. |
| `classes` | The classes, as an Array. |
| `style` | The declarations of the `style` attribute, as a Hash with lowercase properties: `{"font-weight" => "bold"}`. |
| `text_content` | The text of the element and its descendants. |
| `children`, `element_children`, `first_element_child` | The children: elements and texts, elements only, the first element. |
| `query("img")` | The first descendant matching a selector, or nil. |
| `matches?("p.lead")` | Whether the element matches a selector. |
| `parent` | The parent element. |

## Markdown

Markdown import builds the elements commonmarker renders for each Markdown node, and applies the same parse rules. To match Markdown, a type matches these elements:

| Markdown | Element |
|---|---|
| Paragraph, heading, blockquote, thematic break | `p`, `h1`…`h6`, `blockquote`, `hr` |
| Bullet list, ordered list, list item | `ul`, `ol` (with `start` when it isn't 1), `li` |
| Code block | `pre` holding a `code` with a `language-…` class from the info string |
| Table | `table`, `tr`, `th` for the first row, `td`, with a `text-align` style for aligned columns |
| Emphasis, strong, strikethrough, inline code | `em`, `strong`, `s`, `code` |
| Link, image | `a` with `href` and `title`, `img` with `src`, `alt` and `title` |
| Hard line break | `br` |

Raw HTML in Markdown goes through HTML import when the herb gem is installed, and stays as text otherwise.

## Markdown export

A node type writes itself in `to_markdown`, with the methods of `Prosemirror::MarkdownSerializer`, ported from prosemirror-markdown's `MarkdownSerializerState`. As in `view_template`, attributes are instance variables, and `node` is the node:

```ruby
class Callout < Prosemirror::NodeType
  def to_markdown(markdown, parent, index)
    markdown.wrap_block("> ", "> **Note:** ", node) { markdown.render_content(node) }
  end
end
```

| Method | Does |
|---|---|
| `write(text)` | Writes text as it is, after closing the previous block. |
| `text(text, escape: true)` | Writes text, escaped. |
| `render_inline(node)` | Writes the node's inline content, with its marks. |
| `render_content(node)` | Writes the node's blocks. |
| `wrap_block(delim, first_delim, node) { … }` | Writes a block with each line prefixed, like `> `. |
| `render_list(node, delim) { \|index\| marker }` | Writes a list. |
| `close_block(node)` | Ends the block: the next one starts after a blank line. |
| `esc(text)`, `url(href)`, `node_html(node)`, `html?` | Escaping, a link destination, a node's HTML, and whether `html: true` was given. |

Without `to_markdown`, a type writes its content.

A mark type declares its syntax with `markdown`, as prosemirror-markdown's mark specs:

```ruby
class Keyboard < Prosemirror::MarkType
  markdown open: "<kbd>", close: "</kbd>", escape: false
end
```

| Option | Meaning |
|---|---|
| `open`, `close` | Strings, or blocks called with the serializer, the mark, the parent node and the index of the marked node. |
| `mixable: true` | The mark can open and close in any order with other mixable marks, like `*` and `**`. |
| `expel_enclosing_whitespace: true` | Spaces at the edges move outside the mark, as emphasis requires. |
| `escape: false` | The content isn't escaped, as in inline code. The mark must come last. |

Without `markdown`, a mark writes its text, or its HTML with `to_markdown(html: true)`.

## Subclassing built-in types

A subclass keeps the name, options, attributes and parse rules of its parent, and can change any of them. Register it with `Schema#with`, which replaces the built-in type with the same name:

```ruby
class Paragraph < Prosemirror::Nodes::Paragraph
  def view_template(&) = p(class: "text-lg", &)
end

Prosemirror.schema = Prosemirror::Schema.tiptap.with(Paragraph)
```

A subclass that declares parse rules replaces the rules of its parent. See the [cookbook](COOKBOOK.md) for more examples.

With `Schema.tiptap(text_align: true)`, paragraphs and headings are `Prosemirror::TextAlign::Paragraph` and `Prosemirror::TextAlign::Heading`: subclass these to keep the alignment. Other types get it by including `Prosemirror::TextAlign`, which declares the `text_align` attribute, and rendering `text_align_style`:

```ruby
class Callout < Prosemirror::NodeType
  include Prosemirror::TextAlign
  group :block
  content "inline*"

  def view_template(&) = aside(style: text_align_style, &)
end
```
