# frozen_string_literal: true
require "graphql"
require "graphql/client/http"
require "minitest/autorun"

class TestHTTP < MiniTest::Test
  def setup
    skip "TestHTTP disabled by default" unless __FILE__ == $PROGRAM_NAME || ENV["TEST_HTTP"]
    fail "You must specify a valid GITHUB_TOKEN env variable" if ENV["GITHUB_TOKEN"].nil?
  end

  def test_execute
    http = GraphQL::Client::HTTP.new("https://api.github.com/graphql") do
      def headers(_context)
        { "User-Agent" => "GraphQL/1.0", "Authorization" => "Bearer #{ENV["GITHUB_TOKEN"]}" }
      end
    end

    document = GraphQL.parse(<<-'GRAPHQL')
      query getRepository($id: ID!) {
        node(id: $id) {
          ... on Repository {
            nameWithOwner
          }
        }
      }
    GRAPHQL

    name = "getRepository"
    variables = { "id" => "MDEwOlJlcG9zaXRvcnk2NDg3MTI1Ng==" }

    expected = {
      "data" => {
        "node" => {
          "nameWithOwner" => "github/graphql-client"
        }
      }
    }
    actual = http.execute(document: document, operation_name: name, variables: variables)
    assert_equal(expected, actual)
  end

  def test_follows_redirects
    http = GraphQL::Client::HTTP.new("https://httpbin.org/redirect-to?url=https%3A%2F%2Fapi.github.com%2Fgraphql") do
      def headers(_context)
        { "User-Agent" => "GraphQL/1.0", "Authorization" => "Bearer #{ENV["GITHUB_TOKEN"]}" }
      end
    end

    document = GraphQL.parse(<<-'GRAPHQL')
      query getRepository($id: ID!) {
        node(id: $id) {
          ... on Repository {
            nameWithOwner
          }
        }
      }
    GRAPHQL

    name = "getRepository"
    variables = { "id" => "MDEwOlJlcG9zaXRvcnk2NDg3MTI1Ng==" }

    expected = {
      "data" => {
        "node" => {
          "nameWithOwner" => "github/graphql-client"
        }
      }
    }
    actual = http.execute(document: document, operation_name: name, variables: variables)
    assert_equal(expected, actual)
  end

  def test_raises_after_too_many_redirects
    http = GraphQL::Client::HTTP.new("https://httpbin.org/redirect-to?#{ "url=https://httpbin.org/redirect-to?" * 11 }") do
      def headers(_context)
        { "User-Agent" => "GraphQL/1.0", "Authorization" => "Bearer #{ENV["GITHUB_TOKEN"]}" }
      end
    end

    document = GraphQL.parse(<<-'GRAPHQL')
      query getRepository($id: ID!) {
        node(id: $id) {
          ... on Repository {
            nameWithOwner
          }
        }
      }
    GRAPHQL

    name = "getRepository"
    variables = { "id" => "MDEwOlJlcG9zaXRvcnk2NDg3MTI1Ng==" }

    expected = {
      "data" => {
        "node" => {
          "nameWithOwner" => "github/graphql-client"
        }
      }
    }

    assert_raises GraphQL::Client::HTTP::TooManyRedirectsError do
      http.execute(document: document, operation_name: name, variables: variables)
    end
  end
end
