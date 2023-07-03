# ProseMirror

Easily convert text or HTML to [ProseMirror](https://prosemirror.net/) JSON.

This gem merges [html_to_prosemirror](https://github.com/etaminstudio/html_to_prosemirror) and [html_to_prosemirror](https://github.com/etaminstudio/html_to_prosemirror) to a single gem.

For instance, it can be used in a Rails app as such:
- implement a [Tiptap](https://tiptap.dev) editor in your forms, instead of `<textarea>`
- save the ProseMirror JSON in a `json` or `jsonb` field in your PostgreSQL database
- in your view, convert the ProseMirror JSON to HTML and render it

The reverse conversion (HTML to ProseMirror) is useful to migrate your existing data.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add prosemirror

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install prosemirror

## Usage

This is a preview of what will be possible with the gem.

### ProseMirror to HTML

```rb
require 'prosemirror'

json = JSON.parse('{"type": "doc", "content": [{ "type": "paragraph", "content": [{ "text": "Hello World!", "type": "text" }] }] }')
pm = Prosemirror::Html::Renderer.new
pm.render(json) # <p>Hello World!</p>
```

### HTML to ProseMirror

```rb
require 'prosemirror'

html = "<p>Hello World!</p>"
pm = Prosemirror::Html::Renderer.new
pm.render(html) # {"type": "doc", "content": [{ "type": "paragraph", "content": [{ "text": "Hello World!", "type": "text" }] }] }
```

### Text to ProseMirror

```rb
require 'prosemirror'

text = "Hello World!"
pm = Prosemirror::Text::Renderer.new
pm.render(text) # {"type": "doc", "content": [{ "type": "paragraph", "content": [{ "text": "Hello World!", "type": "text" }] }] }
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/etaminstudio/prosemirror.
