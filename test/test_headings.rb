# frozen_string_literal: true

require "test_helper"

class TestHeadings < Minitest::Test
  include TestHelpers

  def heading(level, value, **attrs) = {"type" => "heading", "attrs" => {"level" => level, **attrs.transform_keys(&:to_s)}, "content" => [text(value)]}

  def document
    Prosemirror.parse(doc(heading(2, "Café & co"), heading(3, "Setup"), paragraph(text("text")), heading(2, "Café & co"), heading(2, "???")))
  end

  def test_headings
    assert_equal [
      {level: 2, text: "Café & co", id: "cafe-co"}, {level: 3, text: "Setup", id: "setup"},
      {level: 2, text: "Café & co", id: "cafe-co-2"}, {level: 2, text: "???", id: "section"}
    ], document.headings
  end

  # An id the editor saved, like Tiptap's UniqueID extension does, is kept, and others avoid it.
  def test_own_ids
    headings = Prosemirror.parse(doc(heading(2, "Setup"), heading(2, "Setup", id: "setup"))).headings

    assert_equal %w[setup-2 setup], headings.map { |entry| entry[:id] }
  end

  # Ids are made as Rails' `parameterize` makes them: underscores are kept, and letters transliterated.
  def test_ids_as_parameterize
    texts = ["snake_case -- and kebab-case", "Straße, Œuvre & Ærø", "été", "日本語 title", "-_-"]
    headings = Prosemirror.parse(doc(*texts.map { |value| heading(2, value) })).headings

    assert_equal %w[snake_case-and-kebab-case strasse-oeuvre-aero ete title _], headings.map { |entry| entry[:id] }
  end

  # With ActiveSupport loaded, its `parameterize` makes them, with the app's transliteration rules.
  def test_ids_with_active_support
    skip "ActiveSupport is loaded" if defined?(ActiveSupport)

    Object.const_set(:ActiveSupport, Module.new)
    ActiveSupport.const_set(:Inflector, Module.new { def self.parameterize(text) = text.sub("ü", "ue").downcase })

    assert_equal "gruess", Prosemirror.parse(doc(heading(2, "Grüss"))).headings.first[:id]
  ensure
    Object.send(:remove_const, :ActiveSupport) if defined?(ActiveSupport) && !ActiveSupport.respond_to?(:version)
  end

  def test_rendering_with_ids
    assert_equal %(<h2 id="cafe-co">Café &amp; co</h2><h3 id="setup">Setup</h3><p>text</p><h2 id="cafe-co-2">Café &amp; co</h2><h2 id="section">???</h2>),
      document.to_html(heading_ids: true)
    assert document.to_html.start_with?("<h2>Café &amp; co</h2>")
  end

  # Subclasses of the built-in heading render the same ids, with `heading_id`.
  def test_custom_headings
    custom = Class.new(Prosemirror::Nodes::Heading) do
      def view_template(&) = tag(:"h#{@level}", id: heading_id, class: "title", &)
    end
    schema = Prosemirror::Schema.tiptap.with(custom)

    assert_equal %(<h2 id="setup" class="title">Setup</h2>), schema.parse(doc(heading(2, "Setup"))).to_html(heading_ids: true)
    assert_equal %(<h2 id="setup" style="text-align: center">Setup</h2>),
      Prosemirror::Schema.tiptap(text_align: true).parse(doc(heading(2, "Setup", textAlign: "center"))).to_html(heading_ids: true)
  end
end
