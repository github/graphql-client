# frozen_string_literal: true
require "graphql"
require "graphql/client/http"
require "minitest/autorun"

class TestHTTP < MiniTest::Test
  CONTEXT_USER = Minitest::Mock.new

  SWAPI = GraphQL::Client::HTTP.new("https://mpjk0plp9.lp.gql.zone/graphql") do
    def headers(context)
      request_json_fields = Hash(JSON.parse(context["request_body"])).keys
      CONTEXT_USER.use_body(request_json_fields)
      { "User-Agent" => "GraphQL/1.0" }
    end
  end

  def test_execute
    skip "TestHTTP disabled by default" unless __FILE__ == $PROGRAM_NAME

    CONTEXT_USER.expect(:use_body, nil, [%w[query variables operationName]])

    document = GraphQL.parse(<<-'GRAPHQL')
      query getCharacter($id: ID!) {
        character(id: $id) {
          name
        }
      }
    GRAPHQL

    name = "getCharacter"
    variables = { "id" => "1001" }

    expected = {
      "data" => {
        "character" => {
          "name" => "Darth Vader"
        }
      }
    }
    actual = SWAPI.execute(document: document, operation_name: name, variables: variables)
    assert_equal(expected, actual)
    assert(CONTEXT_USER.verify)
  end
end
