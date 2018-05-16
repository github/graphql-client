# frozen_string_literal: true
require "test_helper"

class TestDefinitionSlice < MiniTest::Test
  def test_slice_simple_query_operation
    document = GraphQL.parse(<<-'GRAPHQL').deep_freeze
      query FooQuery {
        node(id: "42") {
          id
        }
      }
    GRAPHQL

    new_document = GraphQL::Language::DefinitionSlice.slice(document, "FooQuery")

    expected = <<-'GRAPHQL'
      query FooQuery {
        node(id: "42") {
          id
        }
      }
    GRAPHQL
    assert_equal expected.gsub(/^      /, "").chomp, new_document.to_query_string
  end

  def test_slice_simple_mutation_operation
    document = GraphQL.parse(<<-'GRAPHQL').deep_freeze
      mutation FooMutation {
        incr {
          count
        }
      }
    GRAPHQL

    new_document = GraphQL::Language::DefinitionSlice.slice(document, "FooMutation")

    expected = <<-'GRAPHQL'
      mutation FooMutation {
        incr {
          count
        }
      }
    GRAPHQL
    assert_equal expected.gsub(/^      /, "").chomp, new_document.to_query_string
  end

  def test_slice_query_with_fragment
    document = GraphQL.parse(<<-'GRAPHQL').deep_freeze
      query FooQuery {
        node(id: "42") {
          ...NodeFragment
        }
      }

      fragment NodeFragment on Node {
        id
      }

      fragment UnusedFragment on Node {
        type
      }
    GRAPHQL

    new_document = GraphQL::Language::DefinitionSlice.slice(document, "FooQuery")

    expected = <<-'GRAPHQL'
      query FooQuery {
        node(id: "42") {
          ...NodeFragment
        }
      }

      fragment NodeFragment on Node {
        id
      }
    GRAPHQL
    assert_equal expected.gsub(/^      /, "").chomp, new_document.to_query_string
  end

  def test_slice_nested_query_with_fragment
    document = GraphQL.parse(<<-'GRAPHQL').deep_freeze
      fragment NodeFragment on Node {
        id
        ...UserFragment
        ...AnotherUserFragment
      }

      query FooQuery {
        node(id: "42") {
          ...NodeFragment
        }
      }

      fragment AnotherUnusedFragment on Project {
        number
      }

      fragment AnotherUserFragment on Node {
        company
      }

      fragment UserFragment on Node {
        name
        ...AnotherUserFragment
      }

      fragment UnusedFragment on Node {
        type
        ...AnotherUnusedFragment
      }
    GRAPHQL

    new_document = GraphQL::Language::DefinitionSlice.slice(document, "FooQuery")

    expected = <<-'GRAPHQL'
      fragment NodeFragment on Node {
        id
        ...UserFragment
        ...AnotherUserFragment
      }

      query FooQuery {
        node(id: "42") {
          ...NodeFragment
        }
      }

      fragment AnotherUserFragment on Node {
        company
      }

      fragment UserFragment on Node {
        name
        ...AnotherUserFragment
      }
    GRAPHQL
    assert_equal expected.gsub(/^      /, "").chomp, new_document.to_query_string
  end
end
