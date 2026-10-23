## [Unreleased]

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
