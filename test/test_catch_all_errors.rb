# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "minitest/autorun"

class TestClientErrors < MiniTest::Test
  InvoiceType = GraphQL::ObjectType.define do
    name "Invoice"
    field :fee_in_cents, types.Int
  end

  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :rescueFromActiveRecordRecordInvalid, InvoiceType do
      resolve ->(_object, _args, _ctx) {
        GraphQL::ExecutionError.new "Validation failed: missing fee_in_cents."
      }
    end
  end

  Schema = GraphQL::Schema.define(query: QueryType)

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

  def test_errors_collection
    Temp.const_set :Query, @client.parse(<<-GRAPHQL
      query {
        rescueFromActiveRecordRecordInvalid {
          fee_in_cents
        }
      }
    GRAPHQL
    )

    assert response = @client.query(Temp::Query)

    assert_equal 1, response.data.errors.size
    assert_equal 1, response.data.errors.count

    assert_equal 1, response.errors.size
    assert_equal 1, response.errors.count
  end
end
