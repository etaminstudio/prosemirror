# frozen_string_literal: true

require "test_helper"

class TestHTMLEntities < Minitest::Test
  def decode(string, attribute: false) = Prosemirror::HTML::Entities.decode(string, attribute:)

  def test_named_and_numeric_references
    assert_equal "é & é é Æ 𝔄", decode("&eacute; &amp; &#233; &#xE9; &AElig; &Afr;")
  end

  def test_references_with_two_code_points
    assert_equal "<⃒", decode("&nvlt;")
  end

  def test_references_without_semicolon
    assert_equal "© ½ ¬it;", decode("&copy &frac12 &notit;")
  end

  def test_unknown_references_stay
    assert_equal "&unknown; &b=2 &", decode("&unknown; &b=2 &")
  end

  def test_in_attributes_a_reference_without_semicolon_before_a_letter_digit_or_equals_stays
    assert_equal "?a=1&copy=2 ©.", decode("?a=1&copy=2 &copy.", attribute: true)
  end

  def test_invalid_code_points
    assert_equal "� � €", decode("&#0; &#xD800; &#x80;")
  end

  def test_long_names
    name = "&#{"a" * 100_000};"

    assert_equal name, decode(name)
  end
end
