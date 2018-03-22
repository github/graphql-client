# frozen_string_literal: true
require "test_helper"

class TestClientSchema < MiniTest::Test
  QueryType = GraphQL::ObjectType.define do
    name "AwesomeQuery"
    field :version, !types.Int
  end

  Schema = GraphQL::Schema.define(query: QueryType)

  def test_load_schema_identity
    schema = GraphQL::Client.load_schema(Schema)
    assert_equal "AwesomeQuery", schema.query.name
  end

  def test_load_schema_from_introspection_query_result
    result = Schema.execute(GraphQL::Introspection::INTROSPECTION_QUERY)
    schema = GraphQL::Client.load_schema(result)
    assert_equal "AwesomeQuery", schema.query.name
  end

  def test_load_schema_from_json_string
    json = JSON.generate(Schema.execute(GraphQL::Introspection::INTROSPECTION_QUERY))
    schema = GraphQL::Client.load_schema(json)
    assert_equal "AwesomeQuery", schema.query.name
  end

  def test_load_schema_ignores_missing_path
    refute GraphQL::Client.load_schema("#{__dir__}/missing-schema.json")
  end

  def test_dump_schema
    schema = GraphQL::Client.dump_schema(Schema)
    assert_kind_of Hash, schema
    assert_equal "AwesomeQuery", schema["data"]["__schema"]["queryType"]["name"]
  end

  def test_dump_schema_io
    buffer = StringIO.new
    GraphQL::Client.dump_schema(Schema, buffer)
    buffer.rewind
    assert_equal "{\n  \"data\"", buffer.read(10)
  end
end
