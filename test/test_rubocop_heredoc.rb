# frozen_string_literal: true
require "test_helper"

class TestRubocopHeredoc < MiniTest::Test
  def setup
    config = RuboCop::Config.new
    @cop = RuboCop::Cop::GraphQL::Heredoc.new(config)
  end

  def test_good_graphql_heredoc
    investigate(@cop, <<-RUBY)
      Query = Client.parse <<'GRAPHQL'
        { version }
GRAPHQL
    RUBY

    assert_empty @cop.offenses.map(&:message)
  end

  def test_good_graphql_dash_heredoc
    investigate(@cop, <<-RUBY)
      Query = Client.parse <<-'GRAPHQL'
        { version }
      GRAPHQL
    RUBY

    assert_empty @cop.offenses.map(&:message)
  end

  def test_good_graphql_squiggly_heredoc
    investigate(@cop, <<-RUBY)
      Query = Client.parse <<~'GRAPHQL'
        { version }
      GRAPHQL
    RUBY

    assert_empty @cop.offenses.map(&:message)
  end

  def test_bad_graphql_heredoc
    investigate(@cop, <<-RUBY)
      Query = Client.parse <<GRAPHQL
        { version }
GRAPHQL
    RUBY

    assert_equal 1, @cop.offenses.count
    assert_equal "GraphQL heredocs should be quoted. <<-'GRAPHQL'", @cop.offenses.first.message
  end

  def test_bad_graphql_dash_heredoc
    investigate(@cop, <<-RUBY)
      Query = Client.parse <<-GRAPHQL
        { version }
      GRAPHQL
    RUBY

    assert_equal 1, @cop.offenses.count
    assert_equal "GraphQL heredocs should be quoted. <<-'GRAPHQL'", @cop.offenses.first.message
  end

  def test_bad_graphql_squiggly_heredoc
    skip if RUBY_VERSION < "2.3"

    investigate(@cop, <<-RUBY)
      Query = Client.parse <<~GRAPHQL
        { version }
      GRAPHQL
    RUBY

    assert_equal 1, @cop.offenses.count
    assert_equal "GraphQL heredocs should be quoted. <<-'GRAPHQL'", @cop.offenses.first.message
  end

  def test_bad_graphql_heredoc_with_interpolation
    investigate(@cop, <<-RUBY)
      field = "version"
      Query = Client.parse <<-GRAPHQL
        { \#{field} }
      GRAPHQL
    RUBY

    assert_equal 2, @cop.offenses.count
    assert_equal "Do not interpolate variables into GraphQL queries, used variables instead.", @cop.offenses[0].message
    assert_equal "GraphQL heredocs should be quoted. <<-'GRAPHQL'", @cop.offenses[1].message
  end

  def test_bad_graphql_multiline_heredoc
    investigate(@cop, <<-RUBY)
      Query = Client.parse <<GRAPHQL
        {
          version
        }
GRAPHQL
    RUBY

    assert_equal 1, @cop.offenses.count
    assert_equal "GraphQL heredocs should be quoted. <<-'GRAPHQL'", @cop.offenses[0].message
  end

  def test_bad_graphql_multiline_dash_heredoc
    investigate(@cop, <<-RUBY)
      Query = Client.parse <<-GRAPHQL
        {
          version
        }
      GRAPHQL
    RUBY

    assert_equal 1, @cop.offenses.count
    assert_equal "GraphQL heredocs should be quoted. <<-'GRAPHQL'", @cop.offenses[0].message
  end

  def test_bad_graphql_multiline_squiggly_heredoc
    skip if RUBY_VERSION < "2.3"

    investigate(@cop, <<-RUBY)
      Query = Client.parse <<~GRAPHQL
        {
          version
        }
      GRAPHQL
    RUBY

    assert_equal 1, @cop.offenses.count
    assert_equal "GraphQL heredocs should be quoted. <<-'GRAPHQL'", @cop.offenses[0].message
  end

  def test_bad_graphql_multiline_heredoc_with_interpolation
    investigate(@cop, <<-RUBY)
      field = "version"
      Query = Client.parse <<-GRAPHQL
        {
          \#{field}
        }
      GRAPHQL
    RUBY

    assert_equal 2, @cop.offenses.count
    assert_equal "Do not interpolate variables into GraphQL queries, used variables instead.", @cop.offenses[0].message
    assert_equal "GraphQL heredocs should be quoted. <<-'GRAPHQL'", @cop.offenses[1].message
  end

  private

  def investigate(cop, src)
    processed_source = RuboCop::ProcessedSource.new(src, RUBY_VERSION.to_f)
    commissioner = RuboCop::Cop::Commissioner.new([cop], [], raise_error: true)
    commissioner.investigate(processed_source)
    commissioner
  end
end
