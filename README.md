# ProseMirror

Render [ProseMirror](https://prosemirror.net) and [Tiptap](https://tiptap.dev) documents to HTML and text, in Ruby.

- HTML is built with [Phlex](https://www.phlex.fun) and escaped as it is written.
- Attributes are typed with [Literal](https://literal.fun).
- Link and image URLs must use an allowed scheme.
- No Rails dependency.

This gem replaces [prosemirror_to_html](https://github.com/etaminstudio/prosemirror_to_html) and [html_to_prosemirror](https://github.com/etaminstudio/html_to_prosemirror). HTML and Markdown import are planned: see the [roadmap](ROADMAP.md).

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

In Rails, `to_html` returns an `html_safe` string. In a Phlex component, use `to_component`:

```ruby
render doc.to_component
```

Documents are `Enumerable`, and nodes support pattern matching:

```ruby
doc.select { |node| node in { type: :heading, attrs: { level: 1 } } }
doc.content.first.text_content
```

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

When an attribute has another name in JSON, declare it with `json:`:

```ruby
prop :text_align, _String?, json: "textAlign"
```

### Content expressions

`content` says which children a node can have. It works like a regular expression, with node names or group names instead of characters:

| Expression | Meaning |
|---|---|
| `"text*"` | zero or more text nodes |
| `"inline*"` | zero or more nodes of the `inline` group (text, hard breaks…) |
| `"block+"` | one or more nodes of the `block` group |
| `"paragraph block*"` | a paragraph, then zero or more blocks |
| `"(table_cell \| table_header)*"` | zero or more cells or header cells |
| `"caption?"` | zero or one caption |
| `"cell{2}"`, `"cell{1,5}"`, `"cell{2,}"` | exactly two, one to five, two or more cells |

A node type joins a group with `group`, for example `group :block`. A node type without `content` has no children, like an image.

The built-in types use these groups: `block` for paragraphs, headings, lists, tables…, `inline` for text and hard breaks, and `list` for lists.

Today, content expressions are used to find the nodes that contain text, for `to_text`. Rendering doesn't check them. They will also be used by HTML import and validation. See [ProseMirror's guide](https://prosemirror.net/docs/guide/#schema.content_expressions) for details.

### Other options

| Node type option | Meaning |
|---|---|
| `group :block, :list` | the groups of the type |
| `content "inline*"` | the allowed children |
| `inline` | the node is inline, like text (also implied by `group :inline`) |
| `marks ""` | the marks allowed inside: names or groups, `"_"` for all, `""` for none |
| `code` | the node contains code |
| `whitespace :pre` | keep whitespace when importing HTML (implied by `code`) |
| `leaf_text "\n"` | the text of a node without children, for `to_text`; also takes a block called with the node |
| `type_name :image_block` | the type name, when it differs from the class name |
| `aliases :figure` | other type names accepted on input |

| Mark type option | Meaning |
|---|---|
| `spanning false` | render one element per node, instead of one for adjacent nodes with the same mark |
| `excludes "_"` | the marks it can't be combined with |
| `group`, `code`, `type_name`, `aliases` | as for node types |

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

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/etaminstudio/prosemirror.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
