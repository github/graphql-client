# frozen_string_literal: true
require "graphql"
require "graphql/client/query_typename"
require "minitest/autorun"

class TestQueryTypename < MiniTest::Test
  GraphQL::DeprecatedDSL.activate if GraphQL::VERSION > "1.8"

  PersonType = GraphQL::ObjectType.define do
    name "Person"
    field :id, types.Int do
      resolve ->(_query, _args, _ctx) {
        42
      }
    end

    connection :friends, -> { PersonConnection } do
      resolve ->(_query, _args, _ctx) {
        [
          OpenStruct.new,
          OpenStruct.new
        ]
      }
    end

    connection :events, -> { EventConnection } do
      resolve ->(_query, _args, _ctx) {
        [
          OpenStruct.new(type: PublicEventType),
          OpenStruct.new(type: PrivateEventType)
        ]
      }
    end

    field :nextEvent, -> { EventInterface } do
      resolve ->(_query, _args, _ctx) {
        OpenStruct.new(type: PublicEventType)
      }
    end
  end

  EventInterface = GraphQL::InterfaceType.define do
    name "Event"
    field :id, types.Int do
      resolve ->(_query, _args, _ctx) {
        42
      }
    end
  end

  PublicEventType = GraphQL::ObjectType.define do
    name "PublicEvent"
    interfaces [EventInterface]
  end

  PrivateEventType = GraphQL::ObjectType.define do
    name "PrivateEvent"
    interfaces [EventInterface]
  end

  EventUnion = GraphQL::UnionType.define do
    name "Events"
    possible_types [PublicEventType, PrivateEventType]
  end

  PersonConnection = PersonType.define_connection do
    name "PersonConnection"
  end

  EventConnection = EventUnion.define_connection do
    name "EventConnection"
  end

  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :me, !PersonType do
      resolve ->(_query, _args, _ctx) {
        OpenStruct.new
      }
    end
  end

  Schema = GraphQL::Schema.define(query: QueryType) do
    resolve_type ->(_type, obj, _ctx) {
      obj.type
    }
  end

  def setup
    @document = GraphQL.parse(<<-'GRAPHQL')
      query FooQuery {
        me {
          id
          __typename
          ...PersonFragment
          nextEvent {
            id
            ...EventFragment
          }
          friends {
            edges {
              node {
                id
              }
            }
          }
          events {
            edges {
              node {
                ... on PublicEvent {
                  id
                }
                ... on PrivateEvent {
                  id
                }
              }
            }
          }
        }
      }

      fragment PersonFragment on Person {
        id
        nextEvent {
          id
        }
      }

      fragment EventFragment on Event {
        id
      }
    GRAPHQL
  end

  def test_insert_typename
    document = GraphQL::Client::QueryTypename.insert_typename_fields(@document)

    expected = <<-'GRAPHQL'
      query FooQuery {
        __typename
        me {
          id
          __typename
          ...PersonFragment
          nextEvent {
            __typename
            id
            ...EventFragment
          }
          friends {
            __typename
            edges {
              __typename
              node {
                __typename
                id
              }
            }
          }
          events {
            __typename
            edges {
              __typename
              node {
                __typename
                ... on PublicEvent {
                  id
                }
                ... on PrivateEvent {
                  id
                }
              }
            }
          }
        }
      }

      fragment PersonFragment on Person {
        __typename
        id
        nextEvent {
          __typename
          id
        }
      }

      fragment EventFragment on Event {
        __typename
        id
      }
    GRAPHQL
    assert_equal expected.gsub(/^      /, "").chomp, document.to_query_string
  end

  def test_insert_schema_aware_typename
    types = GraphQL::Client::DocumentTypes.analyze_types(Schema, @document)
    document = GraphQL::Client::QueryTypename.insert_typename_fields(@document, types: types)

    expected = <<-'GRAPHQL'
      query FooQuery {
        me {
          id
          __typename
          ...PersonFragment
          nextEvent {
            __typename
            id
            ...EventFragment
          }
          friends {
            edges {
              node {
                id
              }
            }
          }
          events {
            edges {
              node {
                __typename
                ... on PublicEvent {
                  id
                }
                ... on PrivateEvent {
                  id
                }
              }
            }
          }
        }
      }

      fragment PersonFragment on Person {
        id
        nextEvent {
          __typename
          id
        }
      }

      fragment EventFragment on Event {
        __typename
        id
      }
    GRAPHQL
    assert_equal expected.gsub(/^      /, "").chomp, document.to_query_string
  end

  def test_insert_typename_on_empty_selections
    document = GraphQL.parse(<<-'GRAPHQL')
      query FooQuery {
        me
      }
    GRAPHQL

    types = GraphQL::Client::DocumentTypes.analyze_types(Schema, document)
    document = GraphQL::Client::QueryTypename.insert_typename_fields(document, types: types)

    expected = <<-'GRAPHQL'
      query FooQuery {
        me {
          __typename
        }
      }
    GRAPHQL
    assert_equal expected.gsub(/^      /, "").chomp, document.to_query_string
  end
end
