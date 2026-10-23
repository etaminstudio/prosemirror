## [Unreleased]

- Render ProseMirror and Tiptap JSON to HTML (`to_html`) and text (`to_text`).
- `Schema.tiptap` and `Schema.prosemirror`, with `case: :camel` for camelCase type names.
- Custom node and mark types, as Phlex components with Literal attributes.
- Invalid attributes are converted, replaced by their default, or removed, and reported with `on_invalid`. `strict: true` raises instead.
- URL scheme allowlist for links and images, and `resolve_url` to rewrite URLs.

## [0.0.1] - 2023-07-03

- Initial release
