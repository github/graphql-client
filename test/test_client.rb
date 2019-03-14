# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "json"
require "minitest/autorun"

class TestClient < MiniTest::Test
  GraphQL::DeprecatedDSL.activate if GraphQL::VERSION > "1.8"

  module NodeType
    include GraphQL::Schema::Interface
    field :id, ID, null: false
  end

  module AdminUser
    include GraphQL::Schema::Interface
    field :password, String, null: false
  end


  class UserType < GraphQL::Schema::Object
    implements NodeType
    implements AdminUser
    field :id, ID, null: false
    field :first_name, String, null: false
    field :last_name, String, null: false
    field :name, String, null: false
    field :login, String, null: false
    field :login_url, String, null: false
    field :profile_name, String, null: false
    field :is_cool, Boolean, null: false
    field :profile_pic, String, null: true do
      argument :size, Int, required: false
    end
    field :repositories, "[TestClient::RepositoryType]", null: false
    field :friends, [UserType], null: false do
      argument :first, Int, required: false
    end
    field :mutual_friends, [UserType], null: false do
      argument :first, Int, required: false
    end
  end

  class OrganizationType < GraphQL::Schema::Object
    implements NodeType
    field :name, String, null: false
  end

  class RepositoryType < GraphQL::Schema::Object
    field :name, String, null: false
    field :owner, UserType, null: false
    field :star_count, Integer, null: false
    field :watchers, [UserType], null: false
  end

  class QueryType < GraphQL::Schema::Object
    field :viewer, UserType, null: false
    field :node, NodeType, null: true do
      argument :id, ID, required: false
    end
    field :user, UserType, null: true do
      argument :id, ID, required: true
    end
    field :organization, OrganizationType, null: true do
      argument :id, ID, required: true
    end
  end

  class StarResult < GraphQL::Schema::Object
    field :repository, RepositoryType, null: false
  end

  class MutationType < GraphQL::Schema::Object
    field :star, StarResult, null: false do
      argument :repository_id, ID, required: true
    end
  end

  class Schema < GraphQL::Schema
    query(QueryType)
    mutation(MutationType)
    if GraphQL::VERSION > "1.9"
      use GraphQL::Execution::Interpreter
      use GraphQL::Analysis::AST
    end
  end

  module Temp
  end

  def setup
    @client = GraphQL::Client.new(schema: Schema.graphql_definition)
    @client.document_tracking_enabled = true
  end

  def teardown
    Temp.constants.each do |sym|
      Temp.send(:remove_const, sym)
    end
  end

  def test_client_parse_anonymous_operation
    Temp.const_set :UserQuery, @client.parse(<<-'GRAPHQL')
      {
        viewer {
          id
          firstName
          lastName
        }
      }
    GRAPHQL

    assert_kind_of GraphQL::Client::OperationDefinition, Temp::UserQuery
    assert_equal "TestClient::Temp::UserQuery", Temp::UserQuery.name
    assert_equal "TestClient__Temp__UserQuery", Temp::UserQuery.definition_name

    assert_kind_of GraphQL::Language::Nodes::OperationDefinition, Temp::UserQuery.definition_node
    assert_equal "TestClient__Temp__UserQuery", Temp::UserQuery.definition_node.name
    assert_equal "query", Temp::UserQuery.definition_node.operation_type

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      query TestClient__Temp__UserQuery {
        viewer {
          id
          firstName
          lastName
        }
      }
    GRAPHQL

    assert_equal(query_string, @client.document.to_query_string)
    assert_equal(query_string, Temp::UserQuery.document.to_query_string)
  end

  def test_client_parse_anonymous_query
    Temp.const_set :UserQuery, @client.parse(<<-'GRAPHQL')
      query {
        viewer {
          id
          firstName
          lastName
        }
      }
    GRAPHQL

    assert_kind_of GraphQL::Client::OperationDefinition, Temp::UserQuery
    assert_equal "TestClient::Temp::UserQuery", Temp::UserQuery.name
    assert_equal "TestClient__Temp__UserQuery", Temp::UserQuery.definition_name

    assert_kind_of GraphQL::Language::Nodes::OperationDefinition, Temp::UserQuery.definition_node
    assert_equal "TestClient__Temp__UserQuery", Temp::UserQuery.definition_node.name
    assert_equal "query", Temp::UserQuery.definition_node.operation_type

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      query TestClient__Temp__UserQuery {
        viewer {
          id
          firstName
          lastName
        }
      }
    GRAPHQL

    assert_equal(query_string, @client.document.to_query_string)
    assert_equal(query_string, Temp::UserQuery.document.to_query_string)
  end

  def test_client_parse_query_document
    Temp.const_set :UserDocument, @client.parse(<<-'GRAPHQL')
      query GetUser {
        viewer {
          id
          firstName
          lastName
        }
      }
    GRAPHQL

    assert_kind_of GraphQL::Client::OperationDefinition, Temp::UserDocument::GetUser
    assert_equal "TestClient::Temp::UserDocument", Temp::UserDocument.name
    assert_equal "TestClient::Temp::UserDocument::GetUser", Temp::UserDocument::GetUser.name
    assert_equal "TestClient__Temp__UserDocument__GetUser", Temp::UserDocument::GetUser.definition_name

    assert_kind_of GraphQL::Language::Nodes::OperationDefinition, Temp::UserDocument::GetUser.definition_node
    assert_equal "TestClient__Temp__UserDocument__GetUser", Temp::UserDocument::GetUser.definition_node.name
    assert_equal "query", Temp::UserDocument::GetUser.definition_node.operation_type

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      query TestClient__Temp__UserDocument__GetUser {
        viewer {
          id
          firstName
          lastName
        }
      }
    GRAPHQL

    assert_equal(query_string, @client.document.to_query_string)
    assert_equal(query_string, Temp::UserDocument::GetUser.document.to_query_string)
  end

  def test_client_parse_anonymous_mutation
    Temp.const_set :StarMutation, @client.parse(<<-'GRAPHQL')
      mutation {
        star(repositoryId: 12345) {
          repository {
            starCount
          }
        }
      }
    GRAPHQL

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      mutation TestClient__Temp__StarMutation {
        star(repositoryId: 12345) {
          repository {
            starCount
          }
        }
      }
    GRAPHQL

    assert_kind_of GraphQL::Client::OperationDefinition, Temp::StarMutation
    assert_equal "TestClient::Temp::StarMutation", Temp::StarMutation.name
    assert_equal "TestClient__Temp__StarMutation", Temp::StarMutation.definition_name

    assert_kind_of GraphQL::Language::Nodes::OperationDefinition, Temp::StarMutation.definition_node
    assert_equal "TestClient__Temp__StarMutation", Temp::StarMutation.definition_node.name
    assert_equal "mutation", Temp::StarMutation.definition_node.operation_type

    assert_equal(query_string, @client.document.to_query_string)
    assert_equal(query_string, Temp::StarMutation.document.to_query_string)
  end

  def test_client_parse_mutation_document
    Temp.const_set :StarDocument, @client.parse(<<-'GRAPHQL')
      mutation StarRepo {
        star(repositoryId: 12345) {
          repository {
            starCount
          }
        }
      }
    GRAPHQL

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      mutation TestClient__Temp__StarDocument__StarRepo {
        star(repositoryId: 12345) {
          repository {
            starCount
          }
        }
      }
    GRAPHQL

    assert_kind_of GraphQL::Client::OperationDefinition, Temp::StarDocument::StarRepo
    assert_equal "TestClient::Temp::StarDocument", Temp::StarDocument.name
    assert_equal "TestClient::Temp::StarDocument::StarRepo", Temp::StarDocument::StarRepo.name
    assert_equal "TestClient__Temp__StarDocument__StarRepo", Temp::StarDocument::StarRepo.definition_name

    assert_kind_of GraphQL::Language::Nodes::OperationDefinition, Temp::StarDocument::StarRepo.definition_node
    assert_equal "TestClient__Temp__StarDocument__StarRepo", Temp::StarDocument::StarRepo.definition_node.name
    assert_equal "mutation", Temp::StarDocument::StarRepo.definition_node.operation_type

    assert_equal(query_string, @client.document.to_query_string)
    assert_equal(query_string, Temp::StarDocument::StarRepo.document.to_query_string)
  end

  def test_client_parse_anonymous_fragment
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        id
        firstName
        lastName
      }
    GRAPHQL

    assert_kind_of GraphQL::Client::FragmentDefinition, Temp::UserFragment
    assert_equal "TestClient::Temp::UserFragment", Temp::UserFragment.name
    assert_equal "TestClient__Temp__UserFragment", Temp::UserFragment.definition_name

    assert_kind_of GraphQL::Language::Nodes::FragmentDefinition, Temp::UserFragment.definition_node
    assert_equal "TestClient__Temp__UserFragment", Temp::UserFragment.definition_node.name

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      fragment TestClient__Temp__UserFragment on User {
        id
        firstName
        lastName
      }
    GRAPHQL

    assert_equal(query_string, Temp::UserFragment.document.to_query_string)
    assert_equal(query_string, @client.document.to_query_string)

    assert_equal "TestClient::Temp::UserFragment", Temp::UserFragment.name
  end

  def test_client_parse_fragment_document
    Temp.const_set :UserDocument, @client.parse(<<-'GRAPHQL')
      fragment UserProfile on User {
        id
        firstName
        lastName
      }
    GRAPHQL

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      fragment TestClient__Temp__UserDocument__UserProfile on User {
        id
        firstName
        lastName
      }
    GRAPHQL

    assert_equal(query_string, Temp::UserDocument::UserProfile.document.to_query_string)
    assert_equal(query_string, @client.document.to_query_string)
  end

  def test_client_parse_query_fragment_document
    Temp.const_set :StandardProfilePic, @client.parse(<<-'GRAPHQL')
      fragment on User {
        profilePic(size: 50)
      }
    GRAPHQL

    Temp.const_set :UserDocument, @client.parse(<<-'GRAPHQL')
      query NestedFragments {
        user(id: 4) {
          friends(first: 10) {
            ...FriendFields
          }
          mutualFriends(first: 10) {
            ...FriendFields
          }
        }
      }

      fragment FriendFields on User {
        id
        name
        ...TestClient::Temp::StandardProfilePic
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document.to_query_string)
      fragment TestClient__Temp__StandardProfilePic on User {
        profilePic(size: 50)
      }

      query TestClient__Temp__UserDocument__NestedFragments {
        user(id: 4) {
          friends(first: 10) {
            ...TestClient__Temp__UserDocument__FriendFields
          }
          mutualFriends(first: 10) {
            ...TestClient__Temp__UserDocument__FriendFields
          }
        }
      }

      fragment TestClient__Temp__UserDocument__FriendFields on User {
        id
        name
        ...TestClient__Temp__StandardProfilePic
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::UserDocument::NestedFragments.document.to_query_string)
      query TestClient__Temp__UserDocument__NestedFragments {
        user(id: 4) {
          friends(first: 10) {
            ...TestClient__Temp__UserDocument__FriendFields
          }
          mutualFriends(first: 10) {
            ...TestClient__Temp__UserDocument__FriendFields
          }
        }
      }

      fragment TestClient__Temp__UserDocument__FriendFields on User {
        id
        name
        ...TestClient__Temp__StandardProfilePic
      }

      fragment TestClient__Temp__StandardProfilePic on User {
        profilePic(size: 50)
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::UserDocument::FriendFields.document.to_query_string)
      fragment TestClient__Temp__UserDocument__FriendFields on User {
        id
        name
        ...TestClient__Temp__StandardProfilePic
      }

      fragment TestClient__Temp__StandardProfilePic on User {
        profilePic(size: 50)
      }
    GRAPHQL

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      fragment TestClient__Temp__StandardProfilePic on User {
        profilePic(size: 50)
      }
    GRAPHQL
    assert_equal(query_string, Temp::StandardProfilePic.document.to_query_string)
  end

  def test_client_parse_query_external_fragments_document
    Temp.const_set :ProfilePictureFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        profilePic(size: 50)
      }
    GRAPHQL

    Temp.const_set :FriendFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        id
        name
        ...TestClient::Temp::ProfilePictureFragment
      }
    GRAPHQL

    Temp.const_set :UserQuery, @client.parse(<<-'GRAPHQL')
      query {
        user(id: 4) {
          friends(first: 10) {
            ...TestClient::Temp::FriendFragment
          }
          mutualFriends(first: 10) {
            ...TestClient::Temp::FriendFragment
          }
        }
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document.to_query_string)
      fragment TestClient__Temp__ProfilePictureFragment on User {
        profilePic(size: 50)
      }

      fragment TestClient__Temp__FriendFragment on User {
        id
        name
        ...TestClient__Temp__ProfilePictureFragment
      }

      query TestClient__Temp__UserQuery {
        user(id: 4) {
          friends(first: 10) {
            ...TestClient__Temp__FriendFragment
          }
          mutualFriends(first: 10) {
            ...TestClient__Temp__FriendFragment
          }
        }
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::UserQuery.document.to_query_string)
      query TestClient__Temp__UserQuery {
        user(id: 4) {
          friends(first: 10) {
            ...TestClient__Temp__FriendFragment
          }
          mutualFriends(first: 10) {
            ...TestClient__Temp__FriendFragment
          }
        }
      }

      fragment TestClient__Temp__FriendFragment on User {
        id
        name
        ...TestClient__Temp__ProfilePictureFragment
      }

      fragment TestClient__Temp__ProfilePictureFragment on User {
        profilePic(size: 50)
      }
    GRAPHQL
  end

  def test_client_parse_query_external_document_fragment
    Temp.const_set :ProfileFragments, @client.parse(<<-'GRAPHQL')
      fragment ProfilePic on User {
        profilePic(size: 50)
      }

      fragment FriendFields on User {
        id
        name
        ...ProfilePic
      }
    GRAPHQL

    Temp.const_set :UserQuery, @client.parse(<<-'GRAPHQL')
      query {
        user(id: 4) {
          friends(first: 10) {
            ...TestClient::Temp::ProfileFragments::FriendFields
          }
          mutualFriends(first: 10) {
            ...TestClient::Temp::ProfileFragments::FriendFields
          }
        }
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document.to_query_string)
      fragment TestClient__Temp__ProfileFragments__ProfilePic on User {
        profilePic(size: 50)
      }

      fragment TestClient__Temp__ProfileFragments__FriendFields on User {
        id
        name
        ...TestClient__Temp__ProfileFragments__ProfilePic
      }

      query TestClient__Temp__UserQuery {
        user(id: 4) {
          friends(first: 10) {
            ...TestClient__Temp__ProfileFragments__FriendFields
          }
          mutualFriends(first: 10) {
            ...TestClient__Temp__ProfileFragments__FriendFields
          }
        }
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::UserQuery.document.to_query_string)
      query TestClient__Temp__UserQuery {
        user(id: 4) {
          friends(first: 10) {
            ...TestClient__Temp__ProfileFragments__FriendFields
          }
          mutualFriends(first: 10) {
            ...TestClient__Temp__ProfileFragments__FriendFields
          }
        }
      }

      fragment TestClient__Temp__ProfileFragments__ProfilePic on User {
        profilePic(size: 50)
      }

      fragment TestClient__Temp__ProfileFragments__FriendFields on User {
        id
        name
        ...TestClient__Temp__ProfileFragments__ProfilePic
      }
    GRAPHQL
  end

  def test_client_parse_multiple_queries
    Temp.const_set :FriendFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        id
        name
      }
    GRAPHQL

    Temp.const_set :FriendsQuery, @client.parse(<<-'GRAPHQL')
      query {
        user(id: 4) {
          friends(first: 10) {
            ...TestClient::Temp::FriendFragment
          }
        }
      }
    GRAPHQL

    Temp.const_set :MutualFriendsQuery, @client.parse(<<-'GRAPHQL')
      query {
        user(id: 4) {
          mutualFriends(first: 10) {
            ...TestClient::Temp::FriendFragment
          }
        }
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document.to_query_string)
      fragment TestClient__Temp__FriendFragment on User {
        id
        name
      }

      query TestClient__Temp__FriendsQuery {
        user(id: 4) {
          friends(first: 10) {
            ...TestClient__Temp__FriendFragment
          }
        }
      }

      query TestClient__Temp__MutualFriendsQuery {
        user(id: 4) {
          mutualFriends(first: 10) {
            ...TestClient__Temp__FriendFragment
          }
        }
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::FriendsQuery.document.to_query_string)
      query TestClient__Temp__FriendsQuery {
        user(id: 4) {
          friends(first: 10) {
            ...TestClient__Temp__FriendFragment
          }
        }
      }

      fragment TestClient__Temp__FriendFragment on User {
        id
        name
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::MutualFriendsQuery.document.to_query_string)
      query TestClient__Temp__MutualFriendsQuery {
        user(id: 4) {
          mutualFriends(first: 10) {
            ...TestClient__Temp__FriendFragment
          }
        }
      }

      fragment TestClient__Temp__FriendFragment on User {
        id
        name
      }
    GRAPHQL
  end

  def test_client_parse_query_external_top_level_fragments_document
    Object.const_set :TopLevelUserFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        profilePic(size: 50)
      }
    GRAPHQL

    Temp.const_set :FriendFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        id
        name
        ...TopLevelUserFragment
      }
    GRAPHQL

    Temp.const_set :UserQuery, @client.parse(<<-'GRAPHQL')
      query {
        user(id: 4) {
          friends(first: 10) {
            ...TestClient::Temp::FriendFragment
          }
          mutualFriends(first: 10) {
            ...TestClient::Temp::FriendFragment
          }
        }
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document.to_query_string)
      fragment TopLevelUserFragment on User {
        profilePic(size: 50)
      }

      fragment TestClient__Temp__FriendFragment on User {
        id
        name
        ...TopLevelUserFragment
      }

      query TestClient__Temp__UserQuery {
        user(id: 4) {
          friends(first: 10) {
            ...TestClient__Temp__FriendFragment
          }
          mutualFriends(first: 10) {
            ...TestClient__Temp__FriendFragment
          }
        }
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::UserQuery.document.to_query_string)
      query TestClient__Temp__UserQuery {
        user(id: 4) {
          friends(first: 10) {
            ...TestClient__Temp__FriendFragment
          }
          mutualFriends(first: 10) {
            ...TestClient__Temp__FriendFragment
          }
        }
      }

      fragment TestClient__Temp__FriendFragment on User {
        id
        name
        ...TopLevelUserFragment
      }

      fragment TopLevelUserFragment on User {
        profilePic(size: 50)
      }
    GRAPHQL
  end

  def test_local_definition
    user_query = @client.parse(<<-'GRAPHQL')
      {
        viewer {
          id
        }
      }
    GRAPHQL

    assert_nil user_query.name
    assert_equal "GraphQL__Client__OperationDefinition_#{user_query.object_id}", user_query.definition_name

    # rubocop:disable GraphQL/Heredoc
    query_string = <<-GRAPHQL.gsub(/^      /, "").chomp
      query GraphQL__Client__OperationDefinition_#{user_query.object_id} {
        viewer {
          id
        }
      }
    GRAPHQL
    # rubocop:enable GraphQL/Heredoc
    assert_equal(query_string, user_query.document.to_query_string)

    skip "anonymous definition should not be tracked in document"
    assert_equal("", @client.document.to_query_string)
  end

  def test_undefine_definition
    Temp.const_set :UserQuery, @client.parse(<<-'GRAPHQL')
      {
        viewer {
          id
        }
      }
    GRAPHQL
    definition = Temp::UserQuery

    assert_equal "TestClient::Temp::UserQuery", definition.name
    assert_equal "TestClient__Temp__UserQuery", definition.definition_name

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      query TestClient__Temp__UserQuery {
        viewer {
          id
        }
      }
    GRAPHQL
    assert_equal(query_string, @client.document.to_query_string)

    Temp.send :remove_const, :UserQuery

    skip "removed definition should not be tracked in document"
  end

  def test_replace_constant
    old_query = @client.parse(<<-'GRAPHQL')
      {
        viewer {
          id
        }
      }
    GRAPHQL
    Temp.const_set :UserQuery, old_query

    # Access UserQuery.name
    Temp::UserQuery.definition_name

    new_query = @client.parse(<<-'GRAPHQL')
      {
        viewer {
          name
        }
      }
    GRAPHQL
    Temp.send :remove_const, :UserQuery
    Temp.const_set :UserQuery, new_query

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      query TestClient__Temp__UserQuery {
        viewer {
          name
        }
      }
    GRAPHQL
    assert_equal(query_string, new_query.document.to_query_string)

    assert_equal <<-'GRAPHQL'.gsub(/^      /, "").chomp, old_query.document.to_query_string
      query TestClient__Temp__UserQuery {
        viewer {
          id
        }
      }
    GRAPHQL

    skip "removed definition should not be tracked in document"

    assert_equal(query_string, @client.document.to_query_string)
  end

  def test_spread_definition_defined_by_other_client
    @client2 = GraphQL::Client.new(schema: Schema)

    Temp.const_set :UserFragment, @client2.parse(<<-'GRAPHQL')
      fragment on User {
        login
      }
    GRAPHQL

    Temp.const_set :RepositoryFragment, @client.parse(<<-'GRAPHQL')
      fragment on Repository {
        name
        owner {
          ...TestClient::Temp::UserFragment
        }
      }
    GRAPHQL

    assert_equal <<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::RepositoryFragment.document.to_query_string
      fragment TestClient__Temp__RepositoryFragment on Repository {
        name
        owner {
          ...TestClient__Temp__UserFragment
        }
      }

      fragment TestClient__Temp__UserFragment on User {
        login
      }
    GRAPHQL
  end
end
