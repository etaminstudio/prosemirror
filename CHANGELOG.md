## [Unreleased]

- Tiptap's YouTube and Twitch embeds, in `Schema.tiptap`: `youtube` and `twitch`, with the video's URL in `src`, rendered as an iframe of its embed URL, built from the video's id. They are imported from Tiptap's markup, and from iframes of embed URLs without it. Subclasses set Twitch's `parent` domain and YouTube's nocookie host. Markdown export writes a link to the video, or the iframe with `html: true`.
- Tiptap's details, in `Schema.tiptap`: `details`, `details_summary` and `details_content`, rendered and imported as Tiptap does, including `<details>` without Tiptap's content wrapper. `open`, which Tiptap keeps with `persist: true`, is rendered and imported. Markdown export writes them as `<details>` HTML around Markdown content, as GitHub reads it.
- `Schema.tiptap(text_align: true)` adds Tiptap's TextAlign extension to headings and paragraphs: a `textAlign` attribute, rendered as a `text-align` style, and imported from it or from the old `align` attribute. Other types get it by including `Prosemirror::TextAlign`.
- Tiptap's task lists, in `Schema.tiptap`: `task_list` and `task_item`, with a `checked` attribute. They render Tiptap's HTML, and are imported from it and from GitHub's. Markdown import reads GitHub Flavored Markdown task lists: a bullet list whose items all have a checkbox is a task list, and other checkboxes stay as text. Markdown export writes `- [x]` items.
- Tiptap's mention node, in `Schema.tiptap`: rendered as `<span data-type="mention">@label</span>`, with its `id`, `label` and `mentionSuggestionChar` in `data-` attributes, and imported from that HTML. Its text is `@label`, or `@id` without a label. In Markdown, it's written as text, or as HTML with `html: true`.

## [0.5.0] - 2026-10-24

- `Document#to_markdown` writes Markdown, with GitHub Flavored Markdown tables and strikethrough, like prosemirror-markdown. Node types write themselves in `to_markdown`, and mark types declare their syntax with `markdown`. `html: true` writes underline, highlight, subscript, superscript and image sizes as HTML.
- `Document#check` accepts attributes whose JSON name differs from their property name, like a link's `class`. It reported them as invalid.
- Faster: parsing JSON takes less than half the time, rendering and `to_h` about a third less, and HTML and Markdown import about a quarter less, with the same results. Strings in documents parsed from a JSON string are frozen, including the values of unknown attributes.

## [0.4.0] - 2026-10-24

- `Document#transform` builds a new document from a block called with each node, children first, which keeps, replaces, removes or splices nodes. Required content that goes missing is added back and reported.
- `Document#check` raises `InvalidDocument` for the first problem with the schema, with its path, and `Document#valid?` returns true or false.
- `Node#blank?` is true for nodes that show nothing, like empty paragraphs.

## [0.3.0] - 2026-10-24

- Import Markdown with `Prosemirror.from_markdown` (or `schema.parse_markdown`). Needs the [`commonmarker`](https://github.com/gjtorikian/commonmarker) gem, which isn't installed with this gem. GitHub Flavored Markdown tables, strikethrough and autolinks are supported, and the schema's parse rules apply, so custom types can match Markdown too. Raw HTML goes through HTML import when the herb gem is installed. YAML front matter is dropped.
- Import plain text with `Prosemirror.from_text` (or `schema.parse_text`): blank lines separate paragraphs, and other line breaks become hard breaks.
- HTML, Markdown and text import accept nil and binary strings, and replace invalid UTF-8 with U+FFFD, as browsers do. HTML import raised on invalid UTF-8.

## [0.2.0] - 2026-10-23

- Import HTML with `Prosemirror.from_html` (or `schema.parse_html`), as ProseMirror's `DOMParser` does. Needs the [`herb`](https://herb-tools.dev) gem, which isn't installed with this gem.
- Node and mark types declare how to recognize them in HTML with `parse_html`, like ProseMirror's parse rules, and attributes with `prop …, parse_html:`. The built-in types have Tiptap's rules.
- Table cells have an `align` attribute (`left`, `right` or `center`), rendered as a `text-align` style.
- `Schema.tiptap` sorts marks in Tiptap's order: `code` now comes before `italic`, and `strike` before `underline`.
- Tiptap's `code` mark can't be combined with other marks, as in Tiptap. `Schema.prosemirror` uses a new `Marks::Basic::Code`, which can.
- `TYPES.md` documents node and mark types: options, attributes, rendering helpers and parse rules.
- Custom types can pass Array, Hash or Date attribute values to Phlex outside Rails. Phlex 2.4.1 raised a `NameError` without the `date` library.

## [0.1.0] - 2026-10-23

- Render ProseMirror and Tiptap JSON to HTML (`to_html`) and text (`to_text`). In Rails, `render doc` works in ERB templates and ViewComponents, and `render doc.to_phlex` in Phlex components.
- `Schema.tiptap` and `Schema.prosemirror`, with `case: :camel` for camelCase type names.
- Custom node and mark types, as Phlex components with Literal attributes.
- Invalid attributes are converted, replaced by their default, or removed, and reported with `on_invalid`. `strict: true` raises instead.
- Attributes a node or mark type doesn't declare are kept in `unknown_attrs`: never rendered, and given back by `to_h`.
- URL scheme allowlist for links and images, and `resolve_url` to rewrite URLs. A URL that `resolve_url` turns into nil is removed and reported.
- A cookbook with recipes: skip empty paragraphs, heading anchors, render your own components, links to records with GlobalID.

## [0.0.1] - 2023-07-03

- Initial release
