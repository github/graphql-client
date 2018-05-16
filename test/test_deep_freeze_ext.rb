# frozen_string_literal: true
require "test_helper"

class TestDeepFreezeExt < MiniTest::Test
  def test_deep_freeze
    document = GraphQL.parse(<<-'GRAPHQL')
      query FooQuery {
        node(id: "4") {
          id
          ... on User {
            name
          }
        }
      }
    GRAPHQL

    query = document.definitions.first
    node_field = query.selections.first
    id_field = node_field.selections.first

    refute document.frozen?
    refute query.frozen?
    refute node_field.frozen?
    refute id_field.frozen?

    document.deep_freeze

    assert document.frozen?
    assert query.frozen?
    assert node_field.frozen?
    assert id_field.frozen?
  end
end
