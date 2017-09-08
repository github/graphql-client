# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "json"
require "minitest/autorun"

class TestVariables < MiniTest::Test
  FormatEnumType = GraphQL::EnumType.define do
    name "Format"
    value "DESKTOP"
    value "MOBILE"
  end

  NestedNestedObjectInput = GraphQL::InputObjectType.define do
    name "NestedNestedObject"
    argument :boolean, types.Boolean
    argument :float, types.Float
    argument :int, types.Int
    argument :string, types.String
  end

  NestedObjectInput = GraphQL::InputObjectType.define do
    name "NestedObject"
    argument :boolean, types.Boolean
    argument :float, types.Float
    argument :int, types.Int
    argument :nestedObject, NestedNestedObjectInput
    argument :string, types.String
  end

  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :coerce, !types.Boolean do
      argument :boolean, types.Boolean
      argument :enum, FormatEnumType
      argument :float, types.Float
      argument :int, types.Int
      argument :nestedObject, NestedObjectInput
      argument :string, types.String
      argument :strings, types[types.String]
    end
  end

  Schema = GraphQL::Schema.define(query: QueryType)
  Client = GraphQL::Client.new(schema: Schema, execute: Schema)

  Query = Client.parse <<-'GRAPHQL'
    query($boolean: Boolean, $enum: Format, $float: Float, $int: Int, $nestedObject: NestedObject, $string: String, $strings: [String]) {
      coerce(boolean: $boolean, enum: $enum, float: $float, int: $int, nestedObject: $nestedObject, string: $string, strings: $strings)
    }
  GRAPHQL

  def test_coerce_boolean
    assert_equal({ "boolean" => nil }, Client.coerce_variables(Query, { "boolean" => nil }))
    assert_equal({ "boolean" => nil }, Client.coerce_variables(Query, { "boolean" => "" }))

    assert_equal({ "boolean" => true }, Client.coerce_variables(Query, { boolean: true }))
    assert_equal({ "boolean" => true }, Client.coerce_variables(Query, { "boolean" => 1 }))
    assert_equal({ "boolean" => true }, Client.coerce_variables(Query, { "boolean" => "1" }))
    assert_equal({ "boolean" => true }, Client.coerce_variables(Query, { "boolean" => "t" }))
    assert_equal({ "boolean" => true }, Client.coerce_variables(Query, { "boolean" => "T" }))
    assert_equal({ "boolean" => true }, Client.coerce_variables(Query, { "boolean" => "true" }))
    assert_equal({ "boolean" => true }, Client.coerce_variables(Query, { "boolean" => "TRUE" }))
    assert_equal({ "boolean" => true }, Client.coerce_variables(Query, { "boolean" => "on" }))
    assert_equal({ "boolean" => true }, Client.coerce_variables(Query, { "boolean" => "ON" }))
    assert_equal({ "boolean" => true }, Client.coerce_variables(Query, { "boolean" => " " }))

    assert_equal({ "boolean" => false }, Client.coerce_variables(Query, { boolean: false }))
    assert_equal({ "boolean" => false }, Client.coerce_variables(Query, { "boolean" => 0 }))
    assert_equal({ "boolean" => false }, Client.coerce_variables(Query, { "boolean" => "0" }))
    assert_equal({ "boolean" => false }, Client.coerce_variables(Query, { "boolean" => "f" }))
    assert_equal({ "boolean" => false }, Client.coerce_variables(Query, { "boolean" => "F" }))
    assert_equal({ "boolean" => false }, Client.coerce_variables(Query, { "boolean" => "false" }))
    assert_equal({ "boolean" => false }, Client.coerce_variables(Query, { "boolean" => "FALSE" }))
    assert_equal({ "boolean" => false }, Client.coerce_variables(Query, { "boolean" => "off" }))
    assert_equal({ "boolean" => false }, Client.coerce_variables(Query, { "boolean" => "OFF" }))
  end

  def test_coerce_string
    assert_equal({ "string" => "42" }, Client.coerce_variables(Query, { "string" => "42" }))
    assert_equal({ "string" => "42" }, Client.coerce_variables(Query, { string: "42" }))
    assert_equal({ "string" => "42" }, Client.coerce_variables(Query, { string: 42 }))
    assert_equal({ "string" => "t" }, Client.coerce_variables(Query, { string: true }))
    assert_equal({ "string" => "f" }, Client.coerce_variables(Query, { string: false }))
  end

  def test_coerce_int
    assert_equal({ "int" => 1 }, Client.coerce_variables(Query, { int: 1 }))
    assert_equal({ "int" => 1 }, Client.coerce_variables(Query, { "int" => "1" }))
    assert_equal({ "int" => 1 }, Client.coerce_variables(Query, { "int" => "1ignore" }))
    assert_equal({ "int" => 0 }, Client.coerce_variables(Query, { "int" => "bad1" }))
    assert_equal({ "int" => 0 }, Client.coerce_variables(Query, { "int" => "bad" }))
    assert_equal({ "int" => 1 }, Client.coerce_variables(Query, { "int" => 1.7 }))
    assert_equal({ "int" => 0 }, Client.coerce_variables(Query, { "int" => false }))
    assert_equal({ "int" => 1 }, Client.coerce_variables(Query, { "int" => true }))
    assert_equal({ "int" => nil }, Client.coerce_variables(Query, { "int" => nil }))
  end

  def test_coerce_float
    assert_equal({ "float" => 1.0 }, Client.coerce_variables(Query, { float: 1.0 }))
    assert_equal({ "float" => 1.0 }, Client.coerce_variables(Query, { "float" => 1 }))
    assert_equal({ "float" => 1.0 }, Client.coerce_variables(Query, { "float" => "1" }))
    assert_equal({ "float" => nil }, Client.coerce_variables(Query, { "float" => nil }))
  end

  def test_coerce_null
    assert_equal({ "string" => nil }, Client.coerce_variables(Query, { "string" => nil }))
  end

  def test_coerce_list
    assert_equal({ "strings" => ["foo", "42", "t", nil] }, Client.coerce_variables(Query, { "strings" => ["foo", 42, true, nil] }))
  end

  def test_coerce_input_object
    assert_equal(
      { "nestedObject" => { "string" => "42" } },
      Client.coerce_variables(Query, { "nestedObject" => { "string" => "42" } })
    )

    assert_equal(
      { "nestedObject" => { "string" => "42" } },
      Client.coerce_variables(Query, { "nestedObject" => { "string" => 42 } })
    )

    assert_equal(
      { "nestedObject" => { "boolean" => true, "string" => "42" } },
      Client.coerce_variables(Query, { "nestedObject" => { "boolean" => true, "string" => 42 } })
    )

    assert_equal(
      { "nestedObject" => { "boolean" => true, "string" => "42" } },
      Client.coerce_variables(Query, { "nestedObject" => { "boolean" => "t", "string" => 42 } })
    )

    assert_equal(
      { "nestedObject" => { "nestedObject" => { "string" => "42" } } },
      Client.coerce_variables(Query, { "nestedObject" => { "nestedObject" => { "string" => 42 } } })
    )
  end

  def test_coerce_enum
    assert_equal({ "enum" => "MOBILE" }, Client.coerce_variables(Query, { "enum" => "MOBILE" }))
    assert_equal({ "enum" => nil }, Client.coerce_variables(Query, { "enum" => "INVALID" }))
  end
end
