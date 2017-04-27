# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "json"
require "minitest/autorun"

class TestClient < MiniTest::Test
  NodeType = GraphQL::InterfaceType.define do
    name "Node"
    field :id, !types.ID
  end

  AdminUser = GraphQL::InterfaceType.define do
    name "AdminUser"
    field :password, !types.String
  end

  UserType = GraphQL::ObjectType.define do
    name "User"
    interfaces [NodeType, AdminUser]
    field :id, !types.ID
    field :firstName, !types.String
    field :lastName, !types.String
    field :name, !types.String
    field :login, !types.String
    field :login_url, !types.String
    field :profileName, !types.String
    field :isCool, !types.Boolean
    field :profilePic, types.String do
      argument :size, types.Int
    end
    field :repositories, !types[!RepositoryType]
    field :friends, -> { !types[!UserType] } do
      argument :first, types.Int
    end
    field :mutualFriends, -> { !types[!UserType] } do
      argument :first, types.Int
    end
  end

  OrganizationType = GraphQL::ObjectType.define do
    name "Organization"
    interfaces [NodeType]
    field :name, !types.String
  end

  RepositoryType = GraphQL::ObjectType.define do
    name "Repository"
    field :name, !types.String
    field :owner, !UserType
    field :starCount, !types.Int
    field :watchers, -> { !types[!UserType] }
  end

  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :viewer, !UserType
    field :node, NodeType do
      argument :id, !types.ID
    end
    field :user, UserType do
      argument :id, !types.ID
    end
    field :organization, OrganizationType do
      argument :id, !types.ID
    end
  end

  StarResult = GraphQL::ObjectType.define do
    name "StarResult"
    field :repository, !RepositoryType
  end

  MutationType = GraphQL::ObjectType.define do
    name "Mutation"
    field :star, !StarResult do
      argument :repositoryID, !types.ID
    end
  end

  Schema = GraphQL::Schema.define(query: QueryType, mutation: MutationType) do
    resolve_type ->(_obj, _ctx) { raise NotImplementedError }
  end

  module Temp
  end

  def setup
    @client = GraphQL::Client.new(schema: Schema)
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
        star(repositoryID: 12345) {
          repository {
            starCount
          }
        }
      }
    GRAPHQL

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      mutation TestClient__Temp__StarMutation {
        star(repositoryID: 12345) {
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
        star(repositoryID: 12345) {
          repository {
            starCount
          }
        }
      }
    GRAPHQL

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      mutation TestClient__Temp__StarDocument__StarRepo {
        star(repositoryID: 12345) {
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

    user = Temp::UserFragment.new("id" => 1, "firstName" => "Joshua", "lastName" => "Peek")
    assert_equal "1", user.id
    assert_equal "Joshua", user.first_name
    assert_equal "Peek", user.last_name

    assert_equal "TestClient::Temp::UserFragment", Temp::UserFragment.name
    assert_equal "TestClient::Temp::UserFragment.type", user.class.name
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
        ...StandardProfilePic
      }

      fragment StandardProfilePic on User {
        profilePic(size: 50)
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document.to_query_string)
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
        ...TestClient__Temp__UserDocument__StandardProfilePic
      }

      fragment TestClient__Temp__UserDocument__StandardProfilePic on User {
        profilePic(size: 50)
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
        ...TestClient__Temp__UserDocument__StandardProfilePic
      }

      fragment TestClient__Temp__UserDocument__StandardProfilePic on User {
        profilePic(size: 50)
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::UserDocument::FriendFields.document.to_query_string)
      fragment TestClient__Temp__UserDocument__FriendFields on User {
        id
        name
        ...TestClient__Temp__UserDocument__StandardProfilePic
      }

      fragment TestClient__Temp__UserDocument__StandardProfilePic on User {
        profilePic(size: 50)
      }
    GRAPHQL

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      fragment TestClient__Temp__UserDocument__StandardProfilePic on User {
        profilePic(size: 50)
      }
    GRAPHQL
    assert_equal(query_string, Temp::UserDocument::StandardProfilePic.document.to_query_string)
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

  def test_client_parse_fragment_query_result_aliases
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        login_url
        profileName
        name: profileName
        isCool
      }
    GRAPHQL

    user = Temp::UserFragment.new("login_url" => "/login", "profileName" => "Josh", "name" => "Josh", "isCool" => true)
    assert_equal "/login", user.login_url
    assert_equal "Josh", user.profile_name
    assert_equal "Josh", user.name
    assert user.is_cool?
  end

  def test_client_parse_fragment_query_result_with_nested_fields
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        id
        repositories {
          name
          watchers {
            login
          }
        }
      }
    GRAPHQL

    user = Temp::UserFragment.new("id" => "1",
                                  "repositories" => [
                                    {
                                      "name" => "github",
                                      "watchers" => [{
                                        "login" => "josh"
                                      }]
                                    }
                                  ])

    assert_equal "1", user.id
    assert_kind_of Array, user.repositories
    assert_equal "github", user.repositories[0].name
    assert_equal "josh", user.repositories[0].watchers[0].login
  end

  def test_client_parse_fragment_query_result_with_inline_fragments
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        id
        repositories {
          ... on Repository {
            name
            watchers {
              ... on User {
                login
              }
            }
          }
        }
      }
    GRAPHQL

    user = Temp::UserFragment.new("id" => "1",
                                  "repositories" => [
                                    {
                                      "name" => "github",
                                      "watchers" => [{
                                        "login" => "josh"
                                      }]
                                    }
                                  ])

    assert_equal "1", user.id
    assert_kind_of Array, user.repositories
    assert_equal "github", user.repositories[0].name
    assert_equal "josh", user.repositories[0].watchers[0].login
  end

  def test_client_parse_nested_inline_fragments_on_same_node
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on Node {
        id
        ... on User {
          login
          ... on AdminUser {
            password
          }
        }
        ... on Organization {
          name
        }
      }
    GRAPHQL

    user = Temp::UserFragment.new("id" => "1",
                                  "login" => "josh",
                                  "password" => "secret")

    assert_equal "1", user.id
    assert_equal "josh", user.login
    assert_equal "secret", user.password
  end

  def test_client_parse_fragment_spread_constant
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
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

    repo = Temp::RepositoryFragment.new("name" => "rails",
                                        "owner" => {
                                          "login" => "josh"
                                        })
    assert_equal "rails", repo.name
    refute repo.owner.respond_to?(:login)

    owner = Temp::UserFragment.new(repo.owner)
    assert_equal "josh", owner.login
  end

  def test_client_parse_fragment_spread_with_inline_fragment
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        login
      }
    GRAPHQL

    Temp.const_set :RepositoryFragment, @client.parse(<<-'GRAPHQL')
      fragment on Repository {
        name
        owner {
          ... on User {
            ...TestClient::Temp::UserFragment
          }
        }
      }
    GRAPHQL

    repo = Temp::RepositoryFragment.new("name" => "rails",
                                        "owner" => {
                                          "login" => "josh"
                                        })
    assert_equal "rails", repo.name
    refute repo.owner.respond_to?(:login)

    owner = Temp::UserFragment.new(repo.owner)
    assert_equal "josh", owner.login

    owner = Temp::UserFragment.new(owner)
    assert_equal "josh", owner.login
  end

  def test_client_parse_invalid_fragment_cast
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        login
      }
    GRAPHQL

    Temp.const_set :RepositoryFragment, @client.parse(<<-'GRAPHQL')
      fragment on Repository {
        name
        owner {
          login
        }
      }
    GRAPHQL

    repo = Temp::RepositoryFragment.new("name" => "rails",
                                        "owner" => {
                                          "login" => "josh"
                                        })

    assert_kind_of Temp::RepositoryFragment.type, repo
    assert_equal "rails", repo.name
    assert_kind_of TestClient::Temp::RepositoryFragment.type[:owner].of_klass, repo.owner
    assert_equal "josh", repo.owner.login

    assert_equal "TestClient::Temp::RepositoryFragment", Temp::RepositoryFragment.name
    assert_equal "TestClient::Temp::RepositoryFragment.type", repo.class.name
    assert_equal "TestClient::Temp::RepositoryFragment.type[:owner]", repo.owner.class.name

    begin
      Temp::UserFragment.new(repo.owner)
      flunk
    rescue TypeError => e
      assert_equal "TestClient::Temp::UserFragment is not included in TestClient::Temp::RepositoryFragment", e.message
    end
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
