# frozen_string_literal: true
require "test_helper"

class TestHTTP < MiniTest::Test
  SWAPI = GraphQL::Client::HTTP.new("https://mpjk0plp9.lp.gql.zone/graphql") do
    def headers(_context)
      { "User-Agent" => "GraphQL/1.0" }
    end
  end

  def test_execute
    skip "TestHTTP disabled by default" unless __FILE__ == $PROGRAM_NAME

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
  end
end
