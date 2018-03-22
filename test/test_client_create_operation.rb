# frozen_string_literal: true
require "test_helper"

class TestClientCreateOperation < MiniTest::Test
  UserType = GraphQL::ObjectType.define do
    name "User"
    field :id, !types.ID
  end

  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :version, !types.Int
    field :user, UserType do
      argument :name, !types.String
    end
    field :users, types[!UserType] do
      argument :name, types.String
      argument :names, types[!types.String]
    end
  end

  UserInput = GraphQL::InputObjectType.define do
    name "CreateUserInput"
    argument :name, !types.String
  end

  MutationType = GraphQL::ObjectType.define do
    name "Mutation"
    field :createUser, UserType do
      argument :input, !UserInput
    end
  end

  Schema = GraphQL::Schema.define(query: QueryType, mutation: MutationType)

  module Temp
  end

  def setup
    @client = GraphQL::Client.new(schema: Schema, execute: Schema)
  end

  def teardown
    Temp.constants.each do |sym|
      Temp.send(:remove_const, sym)
    end
  end

  def test_query_from_fragment_with_on_wrong_query_type
    Temp.const_set :Fragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        id
      }
    GRAPHQL

    assert_raises GraphQL::Client::Error, "Fragment must be defined on Query, Mutation" do
      @client.create_operation(Temp::Fragment)
    end
  end

  def test_query_from_fragment_with_no_variables
    Temp.const_set :Fragment, @client.parse(<<-'GRAPHQL')
      fragment on Query {
        version
      }
    GRAPHQL

    Temp.const_set :Query, @client.create_operation(Temp::Fragment)

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      query TestClientCreateOperation__Temp__Query {
        ...TestClientCreateOperation__Temp__Fragment
      }

      fragment TestClientCreateOperation__Temp__Fragment on Query {
        version
      }
    GRAPHQL
    assert_equal(query_string, Temp::Query.document.to_query_string)
  end

  def test_query_from_fragment_with_one_non_nullable_scalar_variables
    Temp.const_set :Fragment, @client.parse(<<-'GRAPHQL')
      fragment on Query {
        user(name: $name) {
          id
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.create_operation(Temp::Fragment)

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      query TestClientCreateOperation__Temp__Query($name: String!) {
        ...TestClientCreateOperation__Temp__Fragment
      }

      fragment TestClientCreateOperation__Temp__Fragment on Query {
        user(name: $name) {
          id
        }
      }
    GRAPHQL
    assert_equal(query_string, Temp::Query.document.to_query_string)
  end

  def test_query_from_fragment_with_one_nullable_scalar_variables
    Temp.const_set :Fragment, @client.parse(<<-'GRAPHQL')
      fragment on Query {
        users(name: $name) {
          id
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.create_operation(Temp::Fragment)

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      query TestClientCreateOperation__Temp__Query($name: String) {
        ...TestClientCreateOperation__Temp__Fragment
      }

      fragment TestClientCreateOperation__Temp__Fragment on Query {
        users(name: $name) {
          id
        }
      }
    GRAPHQL
    assert_equal(query_string, Temp::Query.document.to_query_string)
  end

  def test_query_from_fragment_with_list_of_scalar_variables
    Temp.const_set :Fragment, @client.parse(<<-'GRAPHQL')
      fragment on Query {
        users(names: $names) {
          id
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.create_operation(Temp::Fragment)

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      query TestClientCreateOperation__Temp__Query($names: [String!]) {
        ...TestClientCreateOperation__Temp__Fragment
      }

      fragment TestClientCreateOperation__Temp__Fragment on Query {
        users(names: $names) {
          id
        }
      }
    GRAPHQL
    assert_equal(query_string, Temp::Query.document.to_query_string)
  end

  def test_mutation_from_fragment_with_input_type_variable
    Temp.const_set :Fragment, @client.parse(<<-'GRAPHQL')
      fragment on Mutation {
        createUser(input: $input) {
          id
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.create_operation(Temp::Fragment)

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      mutation TestClientCreateOperation__Temp__Query($input: CreateUserInput!) {
        ...TestClientCreateOperation__Temp__Fragment
      }

      fragment TestClientCreateOperation__Temp__Fragment on Mutation {
        createUser(input: $input) {
          id
        }
      }
    GRAPHQL
    assert_equal(query_string, Temp::Query.document.to_query_string)
  end
end
