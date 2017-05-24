# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "graphql/client/decorator"
require "minitest/autorun"
require "ostruct"

class TestDecorator < MiniTest::Test
  PersonType = GraphQL::ObjectType.define do
    name "Person"
    field :login, types.String
    field :firstName, types.String
    field :lastName, types.String
  end

  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :me, !PersonType do
      resolve ->(_query, _args, _ctx) {
        OpenStruct.new(
          login: "josh",
          firstName: "Joshua",
          lastName: "Peek"
        )
      }
    end
  end

  Schema = GraphQL::Schema.define(query: QueryType)

  Client = GraphQL::Client.new(schema: Schema, execute: Schema, enforce_collocated_callers: true)

  extend GraphQL::Client::Decorator


  Person = Client.parse(<<-'GRAPHQL')
    fragment on Person {
      login
      firstName
      lastName
    }
  GRAPHQL

  def format_person_name(person)
    "@#{person.login} (#{person.first_name} #{person.last_name})"
  end
  decorate_fragment :format_person_name, [Person]


  Query = Client.parse(<<-'GRAPHQL')
    {
      me {
        ...TestDecorator::Person
      }
    }
  GRAPHQL

  def test_decorated_format_person_name
    response = Client.query(Query)
    assert_equal "@josh (Joshua Peek)", format_person_name(response.data.me)
  end
end
