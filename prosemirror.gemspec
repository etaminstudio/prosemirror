# frozen_string_literal: true

require_relative "lib/prosemirror/version"

Gem::Specification.new do |spec|
  spec.name = "prosemirror"
  spec.version = Prosemirror::VERSION
  spec.authors = ["Hans Lemuet"]
  spec.email = ["hans@etamin.studio"]

  spec.summary = "Convert ProseMirror and Tiptap documents to and from HTML, Markdown and plain text."
  spec.description = "One schema renders, imports and exports ProseMirror and Tiptap JSON. HTML is built " \
                     "with Phlex and escaped as it is written, and attributes are typed. Node and mark " \
                     "types are Ruby classes. No Rails dependency."
  spec.homepage = "https://github.com/etaminstudio/prosemirror"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["source_code_uri"] = "https://github.com/etaminstudio/prosemirror"
  spec.metadata["changelog_uri"] = "https://github.com/etaminstudio/prosemirror/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://github.com/etaminstudio/prosemirror#readme"
  spec.metadata["bug_tracker_uri"] = "https://github.com/etaminstudio/prosemirror/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[benchmark/ bin/ test/ spec/ features/ .git .circleci .standard.yml appveyor Gemfile Rakefile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "literal", "~> 1.9"
  spec.add_dependency "phlex", "~> 2.4"
  spec.add_dependency "zeitwerk", "~> 2.6"
end
