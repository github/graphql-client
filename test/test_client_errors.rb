# frozen_string_literal: true
require "test_helper"

class TestClientErrors < MiniTest::Test
  GraphQL::DeprecatedDSL.activate if GraphQL::VERSION > "1.8"

  FooType = GraphQL::ObjectType.define do
    name "Foo"
    field :nullableError, types.String do
      resolve ->(_query, _args, _ctx) { raise GraphQL::ExecutionError, "b00m" }
    end
    field :nonnullableError, !types.String do
      resolve ->(_query, _args, _ctx) { raise GraphQL::ExecutionError, "b00m" }
    end
  end

  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :version, !types.Int do
      resolve ->(_query, _args, _ctx) { 1 }
    end
    field :node, FooType do
      resolve ->(_query, _args, _ctx) { GraphQL::ExecutionError.new("missing node") }
    end
    field :nodes, !types[FooType] do
      resolve ->(_query, _args, _ctx) { [GraphQL::ExecutionError.new("missing node"), {}] }
    end
    field :nullableError, types.String do
      resolve ->(_query, _args, _ctx) { raise GraphQL::ExecutionError, "b00m" }
    end
    field :nonnullableError, !types.String do
      resolve ->(_query, _args, _ctx) { raise GraphQL::ExecutionError, "b00m" }
    end
    field :foo, !FooType do
      resolve ->(_query, _args, _ctx) { {} }
    end
    field :foos, types[!FooType] do
      resolve ->(_query, _args, _ctx) { [{}, {}] }
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

  def test_normalize_error_path
    actual = {
      "data" => nil,
      "errors" => [
        {
          "message" => "error"
        }
      ]
    }
    GraphQL::Client::Errors.normalize_error_paths(actual["data"], actual["errors"])
    expected = {
      "data" => nil,
      "errors" => [
        {
          "message" => "error",
          "normalizedPath" => %w(data)
        }
      ]
    }
    assert_equal expected, actual

    actual = {
      "data" => {
        "node" => nil
      },
      "errors" => [
        {
          "message" => "error",
          "path" => %w(node)
        }
      ]
    }
    GraphQL::Client::Errors.normalize_error_paths(actual["data"], actual["errors"])
    expected = {
      "data" => {
        "node" => nil
      },
      "errors" => [
        {
          "message" => "error",
          "path" => %w(node),
          "normalizedPath" => %w(data node)
        }
      ]
    }
    assert_equal expected, actual

    actual = {
      "data" => nil,
      "errors" => [
        {
          "message" => "error",
          "path" => %w(node projects owner)
        }
      ]
    }
    GraphQL::Client::Errors.normalize_error_paths(actual["data"], actual["errors"])
    expected = {
      "data" => nil,
      "errors" => [
        {
          "message" => "error",
          "path" => %w(node projects owner),
          "normalizedPath" => %w(data)
        }
      ]
    }
    assert_equal expected, actual

    actual = {
      "data" => {
        "node" => nil
      },
      "errors" => [
        {
          "message" => "error",
          "path" => %w(node projects owner)
        }
      ]
    }
    GraphQL::Client::Errors.normalize_error_paths(actual["data"], actual["errors"])
    expected = {
      "data" => {
        "node" => nil
      },
      "errors" => [
        {
          "message" => "error",
          "path" => %w(node projects owner),
          "normalizedPath" => %w(data node)
        }
      ]
    }
    assert_equal expected, actual
  end

  def test_filter_nested_errors_by_path
    raw_errors = [
      {
        "message" => "1",
        "normalizedPath" => %w(node id)
      },
      {
        "message" => "2",
        "normalizedPath" => %w(node owner name)
      },
      {
        "message" => "3",
        "normalizedPath" => ["node", "repositories", 0, "name"]
      },
      {
        "message" => "4",
        "normalizedPath" => ["version"]
      }
    ]

    errors = GraphQL::Client::Errors.new(raw_errors, [], true)
    assert_equal 4, errors.count
    assert_equal({ "node" => %w(1 2 3), "version" => ["4"] }, errors.messages.to_h)

    errors = GraphQL::Client::Errors.new(raw_errors, ["node"], true)
    assert_equal 3, errors.count
    assert_equal({ "id" => ["1"], "owner" => ["2"], "repositories" => ["3"] }, errors.messages.to_h)

    errors = GraphQL::Client::Errors.new(raw_errors, ["version"], true)
    assert_empty errors
  end

  def test_filter_direct_errors_by_path
    raw_errors = [
      {
        "message" => "1",
        "normalizedPath" => %w(node id)
      },
      {
        "message" => "2",
        "normalizedPath" => %w(node owner name)
      },
      {
        "message" => "3",
        "normalizedPath" => ["node", "repositories", 0, "name"]
      },
      {
        "message" => "4",
        "normalizedPath" => ["version"]
      }
    ]

    errors = GraphQL::Client::Errors.new(raw_errors, [], false)
    assert_equal 1, errors.count
    assert_equal({ "version" => ["4"] }, errors.messages.to_h)

    errors = GraphQL::Client::Errors.new(raw_errors, ["node"], false)
    assert_equal 1, errors.count
    assert_equal({ "id" => ["1"] }, errors.messages.to_h)

    errors = GraphQL::Client::Errors.new(raw_errors, %w(node owner), false)
    assert_equal 1, errors.count
    assert_equal({ "name" => ["2"] }, errors.messages.to_h)

    errors = GraphQL::Client::Errors.new(raw_errors, ["node", "repositories", 0], false)
    assert_equal 1, errors.count
    assert_equal({ "name" => ["3"] }, errors.messages.to_h)

    errors = GraphQL::Client::Errors.new(raw_errors, ["version"], false)
    assert_empty errors
  end

  def test_errors_collection
    Temp.const_set :Query, @client.parse("{ nullableError }")
    assert response = @client.query(Temp::Query)

    assert_nil response.data.nullable_error

    assert_equal false, response.data.errors.empty?
    assert_equal false, response.data.errors.blank?

    assert_equal 1, response.data.errors.size
    assert_equal 1, response.data.errors.count

    assert_equal true, response.data.errors.include?(:nullableError)
    assert_equal true, response.data.errors.include?("nullableError")
    assert_equal true, response.data.errors.include?(:nullable_error)
    assert_equal true, response.data.errors[:nullableError].any?
    assert_equal true, response.data.errors["nullableError"].any?
    assert_equal true, response.data.errors[:nullable_error].any?

    assert_equal false, response.data.errors.include?(:missingError)
    assert_equal false, response.data.errors.include?("missingError")
    assert_equal false, response.data.errors.include?(:missing_error)
    assert_equal false, response.data.errors[:missingError].any?
    assert_equal false, response.data.errors["missingError"].any?
    assert_equal false, response.data.errors[:missing_error].any?

    assert_equal "b00m", response.data.errors[:nullableError][0]
    assert_equal "b00m", response.data.errors[:nullable_error][0]

    assert_equal "b00m", response.data.errors.messages["nullableError"][0]

    detail = {
      "message" => "b00m",
      "locations" => [{ "line" => 1, "column" => 3 }],
      "path" => %w(nullableError),
      "normalizedPath" => %w(data nullableError)
    }
    assert_equal(detail, response.data.errors.details["nullableError"][0])

    assert_equal [%w(nullableError b00m)], response.data.errors.each.to_a
    assert_equal ["nullableError"], response.data.errors.keys
    assert_equal [["b00m"]], response.data.errors.values

    assert_equal({
      "data" => {
        "nullableError" => nil
      },
      "errors" => [
        {
          "message" => "b00m",
          "locations" => [{"line" => 1, "column" => 3}],
          "path" => ["nullableError"]
        }
      ]
    }, response.to_h)
  end

  def test_nested_errors
    Temp.const_set :Query, @client.parse("{ foo { nullableError } }")
    assert response = @client.query(Temp::Query)

    assert response.data.foo
    assert_empty response.data.errors
    assert_equal "b00m", response.data.errors.all["foo"][0]

    assert_nil response.data.foo.nullable_error
    assert_equal "b00m", response.data.foo.errors["nullableError"][0]
    assert_equal "b00m", response.data.foo.errors.all["nullableError"][0]
  end

  def test_nonnullable_root_error
    Temp.const_set :Query, @client.parse("{ version, nonnullableError }")
    assert response = @client.query(Temp::Query)

    assert_nil response.data
    refute_empty response.errors
    assert_equal "b00m", response.errors[:data][0]
    assert_equal "b00m", response.errors.all[:data][0]
  end

  def test_nonnullable_nested_error
    Temp.const_set :Query, @client.parse("{ version, foo { nonnullableError } }")
    assert response = @client.query(Temp::Query)

    assert_nil response.data
    refute_empty response.errors
    assert_equal "b00m", response.errors[:data][0]
    assert_equal "b00m", response.errors.all[:data][0]
  end

  def test_collection_errors
    Temp.const_set :Query, @client.parse("{ foos { nullableError } }")
    assert response = @client.query(Temp::Query)

    assert response.data.foos
    assert_empty response.data.errors
    assert_equal "b00m", response.data.errors.all["foos"][0]
    assert_equal "b00m", response.data.errors.all["foos"][1]

    assert_nil response.data.foos[0].nullable_error
    assert_equal "b00m", response.data.foos[0].errors["nullableError"][0]
    assert_equal "b00m", response.data.foos[0].errors.all["nullableError"][0]
  end

  def test_node_errors
    Temp.const_set :Query, @client.parse("{ node { __typename } nodes { __typename } }")
    assert response = @client.query(Temp::Query)

    assert_nil response.data.node
    assert_nil response.data.nodes[0]
    assert response.data.nodes[1]
    assert_equal "Foo", response.data.nodes[1].__typename

    refute_empty response.data.errors
    assert_equal "missing node", response.data.errors["node"][0]
    assert_equal "missing node", response.data.nodes.errors[0][0]
  end
end
