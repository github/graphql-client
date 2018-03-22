# frozen_string_literal: true
require "test_helper"

class TestDefinitionVariables < MiniTest::Test
  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :version, !types.Int
    field :user, !types.String do
      argument :name, !types.String
      argument :maybeName, types.String
    end
    field :node, !types.String do
      argument :id, !types.ID
    end
  end

  UserInput = GraphQL::InputObjectType.define do
    name "CreateUserInput"
    argument :name, !types.String
  end

  MutationType = GraphQL::ObjectType.define do
    name "Mutation"
    field :createUser, types.String do
      argument :input, !UserInput
    end
  end

  Schema = GraphQL::Schema.define(query: QueryType, mutation: MutationType)

  def test_query_with_no_variables
    document = GraphQL.parse <<-'GRAPHQL'
      query {
        version
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert variables.empty?
  end

  def test_fragment_with_no_variables
    document = GraphQL.parse <<-'GRAPHQL'
      fragment on Query {
        version
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert variables.empty?
  end

  def test_query_with_one_variable
    document = GraphQL.parse <<-'GRAPHQL'
      query {
        user(name: $name)
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert_kind_of GraphQL::NonNullType, variables[:name]
    assert_equal GraphQL::STRING_TYPE, variables[:name].unwrap

    variables = GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    assert_equal ["$name: String!"], variables.map(&:to_query_string)
  end

  def test_query_with_one_nested_variable
    document = GraphQL.parse <<-'GRAPHQL'
      query {
        ...Foo
      }

      fragment Foo on Query {
        user(name: $name)
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert_kind_of GraphQL::NonNullType, variables[:name]
    assert_equal GraphQL::STRING_TYPE, variables[:name].unwrap

    variables = GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    assert_equal ["$name: String!"], variables.map(&:to_query_string)
  end

  def test_query_with_unused_nested_variable
    document = GraphQL.parse <<-'GRAPHQL'
      query {
        ...One
      }

      fragment One on Query {
        one: user(name: $one)
      }

      fragment Two on Query {
        two: user(name: $two)
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert_kind_of GraphQL::NonNullType, variables[:one]
    assert_equal GraphQL::STRING_TYPE, variables[:one].unwrap
    assert_equal false, variables.key?(:two)

    variables = GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    assert_equal ["$one: String!"], variables.map(&:to_query_string)
  end

  def test_query_nullable_and_nonnullable_variables
    document = GraphQL.parse <<-'GRAPHQL'
      query {
        one: user(name: $foo, maybeName: $bar)
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert_kind_of GraphQL::NonNullType, variables[:foo]
    assert_equal GraphQL::STRING_TYPE, variables[:foo].unwrap
    assert_equal GraphQL::STRING_TYPE, variables[:bar]

    variables = GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    assert_equal ["$foo: String!", "$bar: String"], variables.map(&:to_query_string)
  end


  def test_query_variable_used_twice
    document = GraphQL.parse <<-'GRAPHQL'
      query {
        one: user(name: $name)
        two: user(name: $name)
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert_kind_of GraphQL::NonNullType, variables[:name]
    assert_equal GraphQL::STRING_TYPE, variables[:name].unwrap

    variables = GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    assert_equal ["$name: String!"], variables.map(&:to_query_string)
  end

  def test_query_same_nullable_and_nonnullable_variables
    document = GraphQL.parse <<-'GRAPHQL'
      query {
        one: user(name: $foo, maybeName: $foo)
        two: user(maybeName: $bar, name: $bar)
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert_kind_of GraphQL::NonNullType, variables[:foo]
    assert_equal GraphQL::STRING_TYPE, variables[:foo].unwrap
    assert_kind_of GraphQL::NonNullType, variables[:bar]
    assert_equal GraphQL::STRING_TYPE, variables[:bar].unwrap

    variables = GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    assert_equal ["$foo: String!", "$bar: String!"], variables.map(&:to_query_string)
  end

  def test_fragment_with_unused_nested_variable
    document = GraphQL.parse <<-'GRAPHQL'
      fragment Root on Query {
        ...One
      }

      fragment One on Query {
        one: user(name: $one)
      }

      fragment Two on Query {
        two: user(name: $two)
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert_kind_of GraphQL::NonNullType, variables[:one]
    assert_equal GraphQL::STRING_TYPE, variables[:one].unwrap
    assert_equal false, variables.key?(:two)

    variables = GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    assert_equal ["$one: String!"], variables.map(&:to_query_string)
  end

  def test_mutation_with_input_type_variable
    document = GraphQL.parse <<-'GRAPHQL'
      mutation {
        createUser(input: $input)
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert_kind_of GraphQL::NonNullType, variables[:input]
    assert_equal UserInput, variables[:input].unwrap

    variables = GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    assert_equal ["$input: CreateUserInput!"], variables.map(&:to_query_string)
  end

  def test_mutation_with_nested_input_type_variable
    document = GraphQL.parse <<-'GRAPHQL'
      mutation {
        createUser(input: { name: $name })
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert_kind_of GraphQL::NonNullType, variables[:name]
    assert_equal GraphQL::STRING_TYPE, variables[:name].unwrap

    variables = GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    assert_equal ["$name: String!"], variables.map(&:to_query_string)
  end

  def test_query_with_one_directive_variables
    document = GraphQL.parse <<-'GRAPHQL'
      query {
        version @skip(if: $should_skip)
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert_kind_of GraphQL::NonNullType, variables[:should_skip]
    assert_equal GraphQL::BOOLEAN_TYPE, variables[:should_skip].unwrap

    variables = GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    assert_equal ["$should_skip: Boolean!"], variables.map(&:to_query_string)
  end

  def test_query_with_conflicting_variable_types
    document = GraphQL.parse <<-'GRAPHQL'
      query {
        node(id: $id)
        user(name: $id)
      }
    GRAPHQL
    definition = document.definitions[0]

    assert_raises GraphQL::Client::ValidationError do
      GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    end

    assert_raises GraphQL::Client::ValidationError do
      GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    end
  end
end
