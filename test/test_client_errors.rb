# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "minitest/autorun"

class TestClientErrors < MiniTest::Test
  class FooType < GraphQL::Schema::Object
    field :nullable_error, String, null: true
    def nullable_error
      raise GraphQL::ExecutionError, "b00m"
    end

    field :nonnullable_error, String, null: false
    def nonnullable_error
      raise GraphQL::ExecutionError, "b00m"
    end
  end

  class QueryType < GraphQL::Schema::Object
    field :version, Int, null: false
    def version
      1
    end

    field :node, FooType, null: true
    def node
      GraphQL::ExecutionError.new("missing node")
    end

    field :nodes, [FooType, null: true], null: false
    def nodes
      [GraphQL::ExecutionError.new("missing node"), {}]
    end

    field :nullable_error, String, null: true
    def nullable_error
      raise GraphQL::ExecutionError, "b00m"
    end

    field :nonnullable_error, String, null: false
    def nonnullable_error
      raise GraphQL::ExecutionError, "b00m"
    end

    field :foo, FooType, null: false
    def foo
      {}
    end

    field :foos, [FooType], null: true
    def foos
      [{}, {}]
    end
  end

  class Schema < GraphQL::Schema
    query(QueryType)

    if defined?(GraphQL::Execution::Interpreter)
      use GraphQL::Execution::Interpreter
      use GraphQL::Analysis::AST
    end
  end

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

    actual = {
      "data" => nil,
      "errors" => [
        {
          "message" => "error",
          "path" => nil
        }
      ]
    }
    GraphQL::Client::Errors.normalize_error_paths(actual["data"], actual["errors"])
    expected = {
      "data" => nil,
      "errors" => [
        {
          "message" => "error",
          "path" => nil,
          "normalizedPath" => %w(data),
        },
      ],
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
    # This list-error handling behavior is broken for class-based schemas that don't use the interpreter.
    # The fix is an `.is_a?` check in `proxy_to_depth` in member_instrumentation.rb
    if defined?(GraphQL::Execution::Interpreter)
      assert_nil response.data.nodes[0]
    end
    assert response.data.nodes[1]
    assert_equal "Foo", response.data.nodes[1].__typename

    refute_empty response.data.errors
    assert_equal "missing node", response.data.errors["node"][0]
    # This error isn't added in class-based schemas + `Execution::Execute`, same bug as above
    if defined?(GraphQL::Execution::Interpreter)
      assert_equal "missing node", response.data.nodes.errors[0][0]
    end
  end
end
