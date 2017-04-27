# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "minitest/autorun"

class TestClientValidation < MiniTest::Test
  UserType = GraphQL::ObjectType.define do
    name "User"
    field :name, !types.String
  end

  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :viewer, !UserType
  end

  Schema = GraphQL::Schema.define(query: QueryType)

  module Temp
  end

  def setup
    @client = GraphQL::Client.new(schema: Schema)
  end

  def teardown
    Temp.constants.each do |sym|
      Temp.send(:remove_const, sym)
    end
  end

  def test_client_parse_query_missing_local_fragment
    Temp.const_set :FooQuery, @client.parse(<<-'GRAPHQL')
      query {
        ...MissingFragment
      }
    GRAPHQL
  rescue GraphQL::Client::ValidationError => e
    assert_equal "#{__FILE__}:#{__LINE__ - 4}", e.backtrace.first
    assert_equal "uninitialized constant MissingFragment", e.message
  else
    flunk "GraphQL::Client::ValidationError expected but nothing was raised"
  end

  def test_client_parse_fragment_missing_local_fragment
    Temp.const_set :FooFragment, @client.parse(<<-'GRAPHQL')
      query {
        ...MissingFragment
      }
    GRAPHQL
  rescue GraphQL::Client::ValidationError => e
    assert_equal "#{__FILE__}:#{__LINE__ - 4}", e.backtrace.first
    assert_equal "uninitialized constant MissingFragment", e.message
  else
    flunk "GraphQL::Client::ValidationError expected but nothing was raised"
  end

  def test_client_parse_query_missing_external_fragment
    Temp.const_set :FooQuery, @client.parse(<<-'GRAPHQL')
      query {
        ...TestClientValidation::Temp::MissingFragment
      }
    GRAPHQL
  rescue GraphQL::Client::ValidationError => e
    assert_equal "#{__FILE__}:#{__LINE__ - 4}", e.backtrace.first
    assert_equal "uninitialized constant TestClientValidation::Temp::MissingFragment", e.message
  else
    flunk "GraphQL::Client::ValidationError expected but nothing was raised"
  end

  def test_client_parse_query_external_fragment_is_wrong_type
    Temp.const_set :Answer, 42

    Temp.const_set :FooQuery, @client.parse(<<-'GRAPHQL')
      query {
        ...TestClientValidation::Temp::Answer
      }
    GRAPHQL
  rescue GraphQL::Client::ValidationError => e
    assert_equal "#{__FILE__}:#{__LINE__ - 4}", e.backtrace.first
    assert_equal "expected TestClientValidation::Temp::Answer to be a " \
      "GraphQL::Client::FragmentDefinition, but was a #{42.class}.", e.message
  else
    flunk "GraphQL::Client::ValidationError expected but nothing was raised"
  end

  def test_client_parse_query_external_fragment_is_module
    Temp.const_set :UserDocument, @client.parse(<<-'GRAPHQL')
      fragment UserFragment on User {
        __typename
      }
    GRAPHQL

    Temp.const_set :FooQuery, @client.parse(<<-'GRAPHQL')
      query {
        ...TestClientValidation::Temp::UserDocument
      }
    GRAPHQL
  rescue GraphQL::Client::ValidationError => e
    assert_equal "#{__FILE__}:#{__LINE__ - 4}", e.backtrace.first
    assert_equal "expected TestClientValidation::Temp::UserDocument to be a " \
      "GraphQL::Client::FragmentDefinition, but was a Module. Did you mean " \
      "TestClientValidation::Temp::UserDocument::UserFragment?", e.message
  else
    flunk "GraphQL::Client::ValidationError expected but nothing was raised"
  end

  def test_client_parse_with_missing_type
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on MissingType {
        __typename
      }
    GRAPHQL
  rescue GraphQL::Client::ValidationError => e
    assert_equal "#{__FILE__}:#{__LINE__ - 5}", e.backtrace.first
    assert_equal "No such type MissingType, so it can't be a fragment condition", e.message
  else
    flunk "GraphQL::Client::ValidationError expected but nothing was raised"
  end

  def test_client_parse_with_missing_field
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        __typename
        missingField
      }
    GRAPHQL
  rescue GraphQL::Client::ValidationError => e
    assert_equal "#{__FILE__}:#{__LINE__ - 4}", e.backtrace.first
    assert_equal "Field 'missingField' doesn't exist on type 'User'", e.message
  else
    flunk "GraphQL::Client::ValidationError expected but nothing was raised"
  end

  def test_client_parse_with_missing_nested_field
    Temp.const_set :UserQuery, @client.parse(<<-'GRAPHQL')
      query {
        viewer {
          name
          missingField
        }
      }
    GRAPHQL
  rescue GraphQL::Client::ValidationError => e
    assert_equal "#{__FILE__}:#{__LINE__ - 5}", e.backtrace.first
    assert_equal "Field 'missingField' doesn't exist on type 'User'", e.message
  else
    flunk "GraphQL::Client::ValidationError expected but nothing was raised"
  end
end
