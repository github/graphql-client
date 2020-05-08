# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "json"
require "minitest/autorun"

class TestClientSchema < MiniTest::Test
  FakeConn = Class.new do
    attr_reader :context

    def headers(_)
     {}
    end

    def execute(document:, operation_name: nil, variables: {}, context: {})
     @context = context
    end
  end

  class AwesomeQueryType < GraphQL::Schema::Object
    field :version, Integer, null: false
  end

  class Schema < GraphQL::Schema
    query(AwesomeQueryType)
  end

  def test_load_schema_identity
    schema = GraphQL::Client.load_schema(Schema)
    assert_equal "AwesomeQuery", schema.query.graphql_name
  end

  def test_load_schema_from_introspection_query_result
    result = Schema.execute(GraphQL::Introspection::INTROSPECTION_QUERY)
    schema = GraphQL::Client.load_schema(result)
    assert_equal "AwesomeQuery", schema.query.graphql_name
  end

  def test_load_schema_from_json_string
    json = JSON.generate(Schema.execute(GraphQL::Introspection::INTROSPECTION_QUERY))
    schema = GraphQL::Client.load_schema(json)
    assert_equal "AwesomeQuery", schema.query.graphql_name
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

  def test_dump_schema_context
    conn = FakeConn.new
    GraphQL::Client.dump_schema(conn, StringIO.new, context: { user_id: 1})
    assert_equal({ user_id: 1 }, conn.context)
  end
end
