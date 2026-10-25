# Cookbook

Short recipes for common needs. Each one replaces a built-in type with a subclass, registered with `Schema#with`:

```ruby
Prosemirror.schema = Prosemirror::Schema.tiptap.with(Paragraph)
```

## Skip empty paragraphs

Editors often leave empty paragraphs, for example after pressing Enter twice. To render nothing for them:

```ruby
class Paragraph < Prosemirror::Nodes::Paragraph
  def view_template(&)
    p(&) unless node.content.empty?
  end
end
```

A paragraph that only holds spaces or line breaks is not empty. To skip those too, use `blank?`, which keeps paragraphs with an inline image or another leaf node:

```ruby
class Paragraph < Prosemirror::Nodes::Paragraph
  def view_template(&)
    p(&) unless node.blank?(prosemirror_schema)
  end
end
```

`to_text` still separates empty paragraphs with a blank line, as ProseMirror does. `to_h` keeps them, so the editor gets the document back unchanged. To remove them from the document itself, see the next recipe.

## Remove empty paragraphs before saving

To clean a document before saving it, remove blank paragraphs with `transform`, along with the list items and lists they leave empty:

```ruby
schema = Prosemirror::Schema.tiptap(case: :camel)  # saves `bulletList`, as Tiptap expects
document = Prosemirror.parse(params[:content], schema:).transform do |node|
  case node
  in { type: :paragraph | :list_item } if node.blank?(schema) then nil
  in { type: :bullet_list | :ordered_list } if node.content.empty? then nil
  else node
  end
end
record.update!(content: document.to_h)
```

Without `case: :camel`, `to_h` writes snake_case type names like `bullet_list`, which Tiptap doesn't read. `blank?` gets the schema so that it knows your custom types: an image block isn't blank. Children are transformed first, so the list sees its remaining items. Attributes the schema doesn't declare are kept. When something the schema requires is gone, like the only paragraph of a list item kept by another rule, `transform` adds it back and reports it with `on_invalid`.

## Tight lists

Editors wrap each list item's text in a paragraph, so lists render as `<li><p>text</p></li>`, with the paragraphs' margins. To render an item of a single paragraph as `<li>text</li>`, as Markdown does for tight lists:

```ruby
class ListItem < Prosemirror::Nodes::ListItem
  def view_template(&)
    paragraph = node.content.first if node.content.size == 1
    return super unless paragraph&.type == :paragraph && paragraph.content.any?

    li { render_content(paragraph.content) }
  end
end
```

Items with several paragraphs or a nested list, and items left empty, render as before.

## Heading anchors

To link to a section, give each heading an `id` made from its text, unless the document already has one:

```ruby
class Heading < Prosemirror::Nodes::Heading
  prop :id, _String?

  def view_template(&)
    tag(:"h#{@level}", id: @id || slug, &)
  end

  private

  # "Café & co" becomes "cafe-co". In Rails, `node.text_content.parameterize` does the same.
  def slug
    slug = node.text_content.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").downcase.gsub(/[^a-z0-9]+/, "-")
    slug = slug.delete_prefix("-").delete_suffix("-")
    slug unless slug.empty?
  end
end
```

A node doesn't see the rest of the document, so two headings with the same text get the same `id`.

## Quotes with their author

A node can render parts of its content in different places, with `node` and `render_content`. Here, a quote's last line, after a line break, is its author:

```ruby
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

## Render your own components

A node type is a Phlex component, so it can render the app's Phlex components:

```ruby
class ImageBlock < Prosemirror::NodeType
  group :block

  prop :src, String
  prop :caption, _String?

  def view_template
    render Components::Figure.new(src: safe_url(@src), caption: @caption)
  end
end
```

In Rails, components that use Rails helpers (`image_tag`, `url_for`…) need a view context. With [`phlex-rails`](https://github.com/yippee-fun/phlex-rails), they get one when the document is rendered with `render doc.to_phlex`, from a Phlex view or an ERB template. The same applies to a ViewComponent: `render FigureComponent.new(…)` works from a node in that case.

`<%= render doc %>` and `to_html` render the document on its own, without a view context, for example in a mailer or a JSON response. To support them, render the component with a controller instead, and output its HTML as is:

```ruby
def view_template
  raw safe(ApplicationController.render(FigureComponent.new(src: @src, caption: @caption), layout: false))
end
```

`raw safe(...)` outputs HTML without escaping it: only use it for HTML built by your own components, never for a value from the document.

## Links to records with GlobalID

Store links to records as GlobalIDs (`gid://app/Page/1`), so they keep working when a record's URL changes, and turn them into URLs when rendering. `resolve_urls` gets all the URLs of a document before rendering it, so its records load in one query:

```ruby
Prosemirror::Schema.tiptap(
  resolve_urls: lambda do |urls|
    gids = urls.select { |url| url.start_with?("gid://") }
    records = GlobalID::Locator.locate_many(gids, ignore_missing: true).index_by { |record| record.to_global_id.to_s }

    urls.to_h do |url|
      next [url, url] unless url.start_with?("gid://")

      [url, records[url]&.then { |record| Rails.application.routes.url_helpers.polymorphic_path(record) }]
    end
  end
)
```

URLs are resolved before the allowed URL schemes are checked, so `gid://` doesn't need to be allowed. When a record doesn't exist, its link is removed, its text is kept, and the problem goes to `on_invalid`.

`resolve_url` is simpler, but runs one query per link:

```ruby
Prosemirror::Schema.tiptap(
  resolve_url: lambda do |url|
    next url unless url.start_with?("gid://")

    record = GlobalID::Locator.locate(url)
    Rails.application.routes.url_helpers.polymorphic_path(record) if record
  end
)
```
