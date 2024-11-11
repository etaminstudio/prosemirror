# ProseMirror

Easily convert text or HTML to [ProseMirror](https://prosemirror.net/) JSON, then render text of HTML from ProseMirror JSON.

This gem merges [html_to_prosemirror](https://github.com/etaminstudio/html_to_prosemirror) and [prosemirror_to_html](https://github.com/etaminstudio/prosemirror_to_html) to a single gem.

For instance, it can be used in a Rails app as such:
- implement a [Tiptap](https://tiptap.dev) editor in your forms, instead of `<textarea>`
- save the ProseMirror JSON in a `json` or `jsonb` field in your PostgreSQL database
- in your view, convert the ProseMirror JSON to HTML and render it

The reverse conversion (HTML to ProseMirror) is useful to migrate your existing data.


> [!WARNING]
> **This README describes our plans for this gem, but nothing is implemented yet.**

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add prosemirror

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install prosemirror

## Usage

```rb
require 'prosemirror'
```

### ProseMirror to HTML

```rb
json = '{"type": "doc", "content": [{ "type": "paragraph", "content": [{ "text": "Hello World!", "type": "text" }] }] }'
Prosemirror.new(json: json).to_html
# <p>Hello World!</p>
```

### ProseMirror to text

```rb
json = '{"type": "doc", "content": [{ "type": "paragraph", "content": [{ "text": "Hello World!", "type": "text" }] }] }'
Prosemirror.new(json: json).to_text
# Hello World!
```

### HTML to ProseMirror

```rb
html = "<p>Hello World!</p>"
Prosemirror.new(html: html).to_json
# {"type": "doc", "content": [{ "type": "paragraph", "content": [{ "text": "Hello World!", "type": "text" }] }] }
```

### Text to ProseMirror

```rb
text = "Hello World!"
Prosemirror.new(text: text).to_json
# {"type": "doc", "content": [{ "type": "paragraph", "content": [{ "text": "Hello World!", "type": "text" }] }] }
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/etaminstudio/prosemirror.
