# frozen_string_literal: true

require "test_helper"

# The examples from MIGRATING.md.
class TestMigrating < Minitest::Test
  include TestHelpers

  class Callout < Prosemirror::NodeType
    group :block
    content "block+"
    prop :tone, _String?

    def view_template(&) = aside(class: ["callout", @tone && "callout-#{@tone}"], &)
  end

  class User < Prosemirror::NodeType
    group :inline
    inline
    prop :id, _String?, parse_html: ->(element) { element["data-id"] }
    parse_html tag: "user-mention"

    def view_template = span(class: "user-mention", data_id: @id)
  end

  def test_custom_node
    json = {type: "doc", content: [{type: "callout", attrs: {tone: "info"}, content: [{type: "paragraph", content: [{type: "text", text: "Hi"}]}]}]}

    assert_equal %(<aside class="callout callout-info"><p>Hi</p></aside>), Prosemirror.parse(json, schema: Prosemirror::Schema.tiptap.with(Callout)).to_html
  end

  def test_user_node
    document = Prosemirror.from_html(%(<p>Hi <user-mention data-id="7"></user-mention></p>), schema: Prosemirror::Schema.tiptap.with(User))

    assert_equal({"type" => "user", "attrs" => {"id" => "7"}}, document.to_h.dig("content", 0, "content", 1))
    assert_equal %(<p>Hi <span class="user-mention" data-id="7"></span></p>), document.to_html
  end
end
