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
document = Prosemirror.parse(params[:content]).transform do |node|
  case node
  in { type: :paragraph | :list_item } if node.blank? then nil
  in { type: :bullet_list | :ordered_list } if node.content.empty? then nil
  else node
  end
end
record.update!(content: document.to_h)
```

Children are transformed first, so the list sees its remaining items. Attributes the schema doesn't declare are kept. When something the schema requires is gone, like the only paragraph of a list item kept by another rule, `transform` adds it back and reports it with `on_invalid`.

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

Store links to records as GlobalIDs (`gid://app/Page/1`), so they keep working when a record's URL changes, and turn them into URLs when rendering:

```ruby
Prosemirror::Schema.tiptap(
  resolve_url: lambda do |url|
    next url unless url.start_with?("gid://")

    record = GlobalID::Locator.locate(url)
    Rails.application.routes.url_helpers.polymorphic_path(record) if record
  end
)
```

`resolve_url` runs before the allowed URL schemes are checked, so `gid://` doesn't need to be allowed. When the record doesn't exist, the link is removed, its text is kept, and the problem goes to `on_invalid`. Each link runs one query.
