# frozen_string_literal: true
require "test_helper"

class TestClientFetch < MiniTest::Test
  GraphQL::DeprecatedDSL.activate if GraphQL::VERSION > "1.8"

  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :version, !types.Int do
      resolve ->(_query, _args, _ctx) { 1 }
    end
    field :error, !types.String do
      resolve ->(_query, _args, _ctx) { raise GraphQL::ExecutionError, "b00m" }
    end
    field :partial_error, types.String do
      resolve ->(_query, _args, _ctx) { raise GraphQL::ExecutionError, "just a little broken" }
    end
    field :variables, !types.Boolean do
      argument :foo, !types.Int

      resolve ->(_query, args, _ctx) {
        args[:foo] == 42
      }
    end
  end

  Schema = GraphQL::Schema.define(query: QueryType)

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

  def test_successful_response
    Temp.const_set :Query, @client.parse("{ version }")
    assert response = @client.query(Temp::Query)
    assert_equal 1, response.data.version
    assert_empty response.errors

    assert_equal({
      "data" => {
        "version" => 1
      }
    }, response.to_h)
  end

  def test_failed_validation_response
    query = GraphQL::ObjectType.define do
      name "Query"
      field :err, types.String
    end
    outdated_schema = GraphQL::Schema.define(query: query) do
      resolve_type ->(_type, _obj, _ctx) { raise NotImplementedError }
    end

    @client = GraphQL::Client.new(schema: outdated_schema, execute: Schema)

    Temp.const_set :Query, @client.parse("{ err }")
    assert response = @client.query(Temp::Query)
    refute response.data

    refute_empty response.errors
    assert_equal "Field 'err' doesn't exist on type 'Query'", response.errors[:data][0]

    refute_empty response.errors.all
    assert_equal "Field 'err' doesn't exist on type 'Query'", response.errors[:data][0]
  end

  def test_failed_response
    Temp.const_set :Query, @client.parse("{ error }")
    assert response = @client.query(Temp::Query)
    refute response.data

    refute_empty response.errors
    assert_equal "b00m", response.errors[:data][0]
  end

  def test_partial_response
    Temp.const_set :Query, @client.parse("{ partial_error }")
    response = @client.query(Temp::Query)

    assert response.data
    assert_nil response.data.partial_error
    refute_empty response.data.errors
    assert_equal "just a little broken", response.data.errors["partial_error"][0]

    assert_empty response.errors
    refute_empty response.errors.all
    assert_equal "just a little broken", response.errors.all[:data][0]
  end

  def test_query_with_string_key_variables
    Temp.const_set :Query, @client.parse("query($foo: Int!) { variables(foo: $foo) }")
    assert response = @client.query(Temp::Query, variables: { "foo" => 42 })
    assert_empty response.errors
    assert_equal true, response.data.variables
  end

  def test_query_with_symbol_key_variables
    Temp.const_set :Query, @client.parse("query($foo: Int!) { variables(foo: $foo) }")
    assert response = @client.query(Temp::Query, variables: { foo: 42 })
    assert_empty response.errors
    assert_equal true, response.data.variables
  end

  def test_dynamic_query_errors
    query = @client.parse("{ version }")

    assert_raises GraphQL::Client::DynamicQueryError do
      @client.query(query)
    end

    @client.allow_dynamic_queries = true
    assert @client.query(query)
  end
end
