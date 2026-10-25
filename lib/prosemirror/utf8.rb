# frozen_string_literal: true

module Prosemirror
  # Imported HTML, Markdown and text, as valid UTF-8.
  # @api private
  module UTF8
    module_function

    # The value as a UTF-8 String: nil becomes empty, other encodings are read as UTF-8 (a binary string
    # from a file or an HTTP body), and invalid bytes become U+FFFD, as browsers do.
    def string(value)
      string = value.to_s
      string = string.dup.force_encoding(Encoding::UTF_8) unless string.encoding == Encoding::UTF_8
      string.valid_encoding? ? string : string.scrub
    end
  end
end
