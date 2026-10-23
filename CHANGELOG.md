## [Unreleased]

- Import HTML with `Prosemirror.from_html` (or `schema.parse_html`), as ProseMirror's `DOMParser` does. Needs the [`herb`](https://herb-tools.dev) gem, which isn't installed with this gem.
- Node and mark types declare how to recognize them in HTML with `parse_html`, like ProseMirror's parse rules, and attributes with `prop …, parse_html:`. The built-in types have Tiptap's rules.
- Table cells have an `align` attribute (`left`, `right` or `center`), rendered as a `text-align` style.
- `Schema.tiptap` sorts marks in Tiptap's order: `code` now comes before `italic`, and `strike` before `underline`.
- Tiptap's `code` mark can't be combined with other marks, as in Tiptap. `Schema.prosemirror` uses a new `Marks::Basic::Code`, which can.

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
