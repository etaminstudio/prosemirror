# frozen_string_literal: true

require "test_helper"

class TestContentExpression < Minitest::Test
  def parse(source) = Prosemirror::ContentExpression.new(source)

  def test_names
    assert_equal %i[paragraph block], parse("paragraph block*").names
    assert_equal %i[table_cell table_header], parse("(table_cell | table_header)*").names
  end

  def test_tree
    assert_equal [:repeat, %i[name block], 1, nil], parse("block+").tree
    assert_equal [:repeat, %i[name caption], 0, 1], parse("caption?").tree
    assert_equal [:repeat, %i[name cell], 2, 2], parse("cell{2}").tree
    assert_equal [:repeat, %i[name cell], 1, 5], parse("cell{1, 5}").tree
    assert_equal [:repeat, %i[name cell], 2, nil], parse("cell{2,}").tree
    assert_equal [:sequence, [%i[name heading], [:repeat, %i[name paragraph], 1, nil]]],
      parse("heading paragraph+").tree
  end

  def test_invalid_expressions
    ["", "(", "a |", "a)", "a{x}", "a $"].each do |source|
      assert_raises(ArgumentError, "for #{source.inspect}") { parse(source) }
    end
  end
end
