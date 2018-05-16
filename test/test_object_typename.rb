# frozen_string_literal: true
require "test_helper"

class TestObjectTypename < MiniTest::Test
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

  def test_define_simple_query_result
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          id
          nextEvent {
            id
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
    GRAPHQL

    response = @client.query(Temp::Query)
    assert data = response.data

    assert_equal "Person", data.me.class.type.name

    assert_equal "PersonConnection", data.me.friends.class.type.name
    assert_equal %w(PersonEdge PersonEdge), data.me.friends.edges.map { |obj| obj.class.type.name }
    assert_equal %w(Person Person), data.me.friends.edges.map(&:node).map { |obj| obj.class.type.name }

    assert_equal "EventConnection", data.me.events.class.type.name
    assert_equal %w(EventsEdge EventsEdge), data.me.events.edges.map { |obj| obj.class.type.name }
    assert_equal %w(PublicEvent PrivateEvent), data.me.events.edges.map(&:node).map { |obj| obj.class.type.name }

    assert_equal "PublicEvent", data.me.next_event.class.type.name
  end
end
