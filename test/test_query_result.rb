# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "minitest/autorun"
require "time" # required for Time#iso8601
require "ostruct"
require_relative "foo_helper"

class TestQueryResult < MiniTest::Test
  GraphQL::DeprecatedDSL.activate if GraphQL::VERSION > "1.8"

  DateTime = GraphQL::ScalarType.define do
    name "DateTime"
    coerce_input ->(value, ctx) do
      Time.iso8601(value)
    end
    coerce_result ->(value, ctx) do
      value.utc.iso8601
    end
  end

  NodeType = GraphQL::InterfaceType.define do
    name "Node"
    field :id, !types.ID
  end

  PlanEnum = GraphQL::EnumType.define do
    name "Plan"
    value("FREE")
    value("SMALL")
    value("LARGE")
  end

  AdminUser = GraphQL::InterfaceType.define do
    name "AdminUser"
    field :password, !types.String
  end

  RepositoryType = GraphQL::ObjectType.define do
    name "Repository"
    field :name, !types.String
    field :owner, !UserType
    field :starCount, !types.Int
    field :watchers, -> { !types[!UserType] }
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
  end

  HumanLike = GraphQL::InterfaceType.define do
    name "HumanLike"
    field :updatedAt, !DateTime
  end

  PersonType = GraphQL::ObjectType.define do
    name "Person"
    interfaces [HumanLike]
    field :login, types.String
    field :name, types.String
    field :firstName, types.String
    field :lastName, types.String
    field :company, types.String
    field :homepageURL, types.String
    field :createdAt, !DateTime
    field :hobbies, types[types.String]
    field :plan, !PlanEnum
  end

  IssueType = GraphQL::ObjectType.define do
    name "Issue"

    field :title, !types.String
    field :assignees, !types[!UserType]
  end

  PullRequestType = GraphQL::ObjectType.define do
    name "PullRequest"

    field :title, !types.String
    field :assignees, !types[!UserType]
  end

  OrganizationType = GraphQL::ObjectType.define do
    name "Organization"
    interfaces [NodeType]
    field :name, !types.String
  end

  BotType = GraphQL::ObjectType.define do
    name "Bot"
    field :login, types.String
  end

  IssueOrPullRequestUnion = GraphQL::UnionType.define do
    name "IssueOrPullRequest"
    possible_types [IssueType, PullRequestType]
  end

  ActorUnion = GraphQL::UnionType.define do
    name "Actor"
    possible_types [PersonType, BotType]
  end

  PersonConnection = PersonType.define_connection do
    name "PersonConnection"
  end

  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :me, !PersonType do
      resolve ->(_query, _args, _ctx) {
        OpenStruct.new(
          login: "josh",
          name: "Josh",
          firstName: "Joshua",
          lastName: "Peek",
          company: "GitHub",
          createdAt: Time.at(0),
          updatedAt: Time.at(1),
          hobbies: ["soccer", "coding"],
          plan: "LARGE"
        )
      }
    end

    field :issueOrPullRequest, !IssueOrPullRequestUnion do
      resolve -> (_query, _args, _ctx) {
        OpenStruct.new({
          type: PullRequestType,
          title: "Some issue",
          assignees: [
            OpenStruct.new(
              login: "josh",
              name: "Josh",
              firstName: "Joshua",
              lastName: "Peek",
              company: "GitHub",
              createdAt: Time.at(0),
              updatedAt: Time.at(1),
              hobbies: ["soccer", "coding"],
              plan: "LARGE"
            )
          ]
        })
      }
    end

    field :userNoHobbies, !PersonType do
      resolve ->(_query, _args, _ctx) {
        OpenStruct.new(
          hobbies: nil
        )
      }
    end

    field :currentActor, !ActorUnion do
      resolve ->(_query, _args, _ctx) {
        OpenStruct.new(
          type: PersonType,
          login: "josh",
          name: "Josh",
          firstName: "Joshua",
          lastName: "Peek",
          updatedAt: Time.at(1),
        )
      }
    end

    connection :users, PersonConnection do
      argument :first, types.Int

      resolve ->(_query, _args, _ctx) {
        [
          OpenStruct.new(login: "josh"),
          OpenStruct.new(login: "mislav")
        ]
      }
    end

    field :node, NodeType do
      argument :id, !types.ID

      resolve ->(_query, args, _ctx) {
        {
          "1" => OpenStruct.new({
            type: UserType,
            id: "1",
            login: "josh",
            password: "secret",
            login_url: "/login",
            profileName: "Josh",
            isCool: true,
            repositories: [
              OpenStruct.new(
                type: RepositoryType,
                name: "github",
                watchers: [
                  OpenStruct.new(login: "josh")
                ]
              )
            ]
          })
        }[args[:id]]
      }
    end

    field :user, UserType do
      argument :id, !types.ID
    end

    field :organization, OrganizationType do
      argument :id, !types.ID
    end

    field :repository, RepositoryType do
      resolve ->(_query, args, _ctx) {
        OpenStruct.new({
          name: "rails",
          owner: OpenStruct.new(type: UserType, login: "josh")
        })
      }
    end
  end

  Schema = GraphQL::Schema.define(query: QueryType) do
    resolve_type -> (_type, obj, _ctx) { obj.type }
  end

  module Temp
  end

  def setup
    @client = GraphQL::Client.new(schema: Schema, execute: Schema, enforce_collocated_callers: true)
  end

  def teardown
    Temp.constants.each do |sym|
      Temp.send(:remove_const, sym)
    end
  end

  def test_define_simple_query_result
    Temp.const_set :Person, @client.parse(<<-'GRAPHQL')
      fragment on Person {
        name
        company
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          ...TestQueryResult::Temp::Person
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)
    refute response.data.me.respond_to?(:name)
    refute response.data.me.respond_to?(:company)

    person = Temp::Person.new(response.data.me)
    assert_equal "Josh", person.name
    assert_equal "GitHub", person.company
  end

  def test_snakecase_field_aliases
    Temp.const_set :Person, @client.parse(<<-'GRAPHQL')
      fragment on Person {
        firstName
        lastName
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          ...TestQueryResult::Temp::Person
        }
      }
    GRAPHQL

    person = Temp::Person.new(@client.query(Temp::Query).data.me)
    raw_result = {"firstName"=>"Joshua", "lastName"=>"Peek"}
    assert_equal raw_result, person.to_h

    assert_equal "Joshua", person.first_name
    assert_equal "Peek", person.last_name
  end

  def test_predicate_aliases
    Temp.const_set :Person, @client.parse(<<-'GRAPHQL')
      fragment on Person {
        name
        homepageURL
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          ...TestQueryResult::Temp::Person
        }
      }
    GRAPHQL

    person = Temp::Person.new(@client.query(Temp::Query).data.me)
    assert_equal true, person.name?
    assert_equal false, person.homepage_url?
  end

  def test_field_aliases
    Temp.const_set :Person, @client.parse(<<-'GRAPHQL')
      fragment on Person {
        nickname: name
        currentCompany: company
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          ...TestQueryResult::Temp::Person
        }
      }
    GRAPHQL

    person = Temp::Person.new(@client.query(Temp::Query).data.me)
    assert_equal "Josh", person.nickname
    assert_equal "GitHub", person.current_company
  end

  def test_no_method_error
    Temp.const_set :Person, @client.parse(<<-'GRAPHQL')
      fragment on Person {
        name
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          ...TestQueryResult::Temp::Person
        }
      }
    GRAPHQL

    person = Temp::Person.new(@client.query(Temp::Query).data.me)

    begin
      person.nickname
      flunk
    rescue GraphQL::Client::UnimplementedFieldError => e
      assert_equal "undefined field `nickname' on Person type. https://git.io/v1y3m", e.to_s
    end
  end

  def test_no_method_when_field_exists_but_was_not_fetched
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          __typename
        }
      }
    GRAPHQL

    person = @client.query(Temp::Query).data.me

    assert_raises GraphQL::Client::UnfetchedFieldError, "unfetched field `name' on Person type. https://git.io/v1y3U" do
      person.name
    end
  end

  def test_no_method_when_snakecase_field_exists_but_was_not_fetched
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          __typename
        }
      }
    GRAPHQL

    person = @client.query(Temp::Query).data.me

    assert_raises GraphQL::Client::UnfetchedFieldError, "unfetched field `firstName' on Person type. https://git.io/v1y3U" do
      person.first_name
    end
  end

  def test_no_method_error_leaked_from_parent
    Temp.const_set :Person, @client.parse(<<-'GRAPHQL')
      fragment on Person {
        __typename
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          name
          ...TestQueryResult::Temp::Person
        }
      }
    GRAPHQL

    person = Temp::Person.new(@client.query(Temp::Query).data.me)

    assert_raises GraphQL::Client::ImplicitlyFetchedFieldError, "implicitly fetched field `name' on Person type. https://git.io/v1yGL" do
      person.name
    end
  end

  def test_no_method_error_snakecase_field_leaked_from_parent
    Temp.const_set :Person, @client.parse(<<-'GRAPHQL')
      fragment on Person {
        __typename
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          firstName
          ...TestQueryResult::Temp::Person
        }
      }
    GRAPHQL

    person = Temp::Person.new(@client.query(Temp::Query).data.me)

    assert_raises GraphQL::Client::ImplicitlyFetchedFieldError, "implicitly fetched field `firstName' on Person type. https://git.io/v1yGL" do
      person.first_name
    end
  end

  def test_no_method_error_leaked_from_child
    Temp.const_set :Person, @client.parse(<<-'GRAPHQL')
      fragment on Person {
        name
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          ...TestQueryResult::Temp::Person
        }
      }
    GRAPHQL

    person = @client.query(Temp::Query).data.me

    assert_raises GraphQL::Client::ImplicitlyFetchedFieldError, "implicitly fetched field `name' on Person type. https://git.io/v1yGL" do
      person.name
    end
  end

  def test_merge_classes
    Temp.const_set :Person, @client.parse(<<-'GRAPHQL')
      fragment on Person {
        ... on Person {
          name
          company
        }

        ... on Person {
          name
          login
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          ...TestQueryResult::Temp::Person
        }
      }
    GRAPHQL

    person = Temp::Person.new(@client.query(Temp::Query).data.me)
    assert_equal "josh", person.login
    assert_equal "Josh", person.name
    assert_equal "GitHub", person.company
  end

  def test_merge_nested_classes
    Temp.const_set :Me, @client.parse(<<-'GRAPHQL')
      fragment on Query {
        ... on Query {
          me {
            name
            company
          }
        }

        ... on Query {
          me {
            name
            login
          }
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        ...TestQueryResult::Temp::Me
      }
    GRAPHQL

    person = Temp::Me.new(@client.query(Temp::Query).data)
    assert_equal "josh", person.me.login
    assert_equal "Josh", person.me.name
    assert_equal "GitHub", person.me.company
  end

  def test_relay_connection_enumerator
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        users(first: 2) {
          edges {
            cursor
            node {
              login
            }
          }
        }
      }
    GRAPHQL

    data = @client.query(Temp::Query).data
    assert_equal 2, data.users.edges.length
    assert_equal "josh", data.users.edges[0].node.login
    assert_equal "mislav", data.users.edges[1].node.login
    assert_equal %w(josh mislav), data.users.edges.map(&:node).map(&:login)
  end

  def test_enum_values
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          name
          plan
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    person = response.data.me
    assert_equal "Josh", person.name
    assert_equal "LARGE", person.plan
  end

  def test_union_values
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        currentActor {
          ... on Person {
            login
          }
          ... on Bot {
            login
          }
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    actor = response.data.current_actor
    assert_equal "Person", actor.class.type.name
    assert_equal "josh", actor.login
  end

  def test_interface_within_union_values
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        currentActor {
          ... on Person {
            login
          }
          ... on HumanLike {
            updatedAt
          }
          ... on Person {
            name
          }
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    actor = response.data.current_actor
    assert_equal "Person", actor.class.type.name
    assert_equal "josh", actor.login
    assert_equal "Josh", actor.name
    assert_equal Time.at(1).utc, actor.updated_at
  end

  def test_date_scalar_casting
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          name
          createdAt
          updatedAt
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    person = response.data.me
    assert_equal "Josh", person.name
    assert_equal Time.at(0), person.created_at
    assert_equal Time.at(1), person.updated_at
  end

  include FooHelper

  def test_source_location
    Temp.const_set :Person, @client.parse(<<-'GRAPHQL')
      fragment on Person {
        name
        company
      }
    GRAPHQL
    assert_equal [__FILE__, __LINE__ - 6], Temp::Person.source_location

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          ...TestQueryResult::Temp::Person
        }
      }
    GRAPHQL
    assert_equal [__FILE__, __LINE__ - 7], Temp::Query.source_location
  end

  def test_non_collocated_caller_error
    Temp.const_set :Person, @client.parse(<<-'GRAPHQL')
      fragment on Person {
        name
        company
        firstName
        lastName
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          ...TestQueryResult::Temp::Person
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    person = Temp::Person.new(response.data.me)
    assert_equal "Josh", person.name
    assert_equal "GitHub", person.company
    assert_equal "Joshua", person.first_name
    assert_equal "Peek", person.last_name

    assert_raises GraphQL::Client::NonCollocatedCallerError do
      format_person_info(person)
    end

    GraphQL::Client.allow_noncollocated_callers do
      assert_equal "Josh works at GitHub", format_person_info(person)
    end

    GraphQL::Client.allow_noncollocated_callers do
      assert_equal true, person_employed?(person)
    end

    GraphQL::Client.allow_noncollocated_callers do
      assert_equal "Joshua Peek", format_person_name(person)
    end

    assert_raises GraphQL::Client::NonCollocatedCallerError do
      format_person_name(person)
    end
  end

  def test_list_of_string_scalar_casting
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          hobbies
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    person = response.data.me
    assert_equal ["soccer", "coding"], person.hobbies
  end

  def test_nullable_list
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        userNoHobbies {
          hobbies
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    person = response.data.user_no_hobbies
    assert_nil person.hobbies
  end

  def test_empty_selection_existence
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me
      }
    GRAPHQL

    response = @client.query(Temp::Query)
    refute response.data.me.nil?
    assert_equal "Person", response.data.me.class.type.name
    assert response.data.me.is_a?(@client.types::Person)
  end

  def test_empty_selection_existence_with_fragment
    Temp.const_set :Fragment, @client.parse(<<-'GRAPHQL')
      fragment on Query {
        me {
          name
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me
        ...TestQueryResult::Temp::Fragment
      }
    GRAPHQL

    response = @client.query(Temp::Query)
    refute response.data.me.nil?
    assert_kind_of @client.types::Person, response.data.me
    assert_equal "Person", response.data.me.class.type.name
    assert response.data.me.is_a?(@client.types::Person)

    person = Temp::Fragment.new(response.data).me
    assert_equal "Josh", person.name
  end

  def test_parse_fragment_query_result_with_nested_fields
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

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        node(id: "1") {
          ...TestQueryResult::Temp::UserFragment
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    user = Temp::UserFragment.new(response.data.node)

    assert_equal "1", user.id
    assert_kind_of Array, user.repositories
    assert_equal "github", user.repositories[0].name
    assert_equal "josh", user.repositories[0].watchers[0].login
  end

  def test_parse_fragment_spread_constant
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        login
      }
    GRAPHQL

    Temp.const_set :RepositoryFragment, @client.parse(<<-'GRAPHQL')
      fragment on Repository {
        name
        owner {
          ...TestQueryResult::Temp::UserFragment
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        repository {
          ...TestQueryResult::Temp::RepositoryFragment
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    repo = Temp::RepositoryFragment.new(response.data.repository)

    assert_equal "rails", repo.name
    refute repo.owner.respond_to?(:login)

    owner = Temp::UserFragment.new(repo.owner)
    assert_equal "josh", owner.login
  end

  def test_parse_nested_inline_fragments_on_same_node
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

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        node(id: "1") {
          ...TestQueryResult::Temp::UserFragment
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    user = Temp::UserFragment.new(response.data.node)

    assert_equal "1", user.id
    assert_equal "josh", user.login
    assert_equal "secret", user.password
  end

  def test_parse_fragment_query_result_aliases
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        login_url
        profileName
        name: profileName
        isCool
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        node(id: "1") {
          ...TestQueryResult::Temp::UserFragment
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    user = Temp::UserFragment.new(response.data.node)

    assert_equal "/login", user.login_url
    assert_equal "Josh", user.profile_name
    assert_equal "Josh", user.name
    assert user.is_cool?
  end

  def test_parse_fragment_spread_with_inline_fragment
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
            ...TestQueryResult::Temp::UserFragment
          }
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        repository {
          ...TestQueryResult::Temp::RepositoryFragment
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    repo = Temp::RepositoryFragment.new(response.data.repository)
    assert_equal "rails", repo.name
    refute repo.owner.respond_to?(:login)

    owner = Temp::UserFragment.new(repo.owner)
    assert_equal "josh", owner.login

    owner = Temp::UserFragment.new(owner)
    assert_equal "josh", owner.login
  end

  def test_parse_fragment_spread_with_local_fragment
    Temp.const_set :Queries, @client.parse(<<-'GRAPHQL')
      fragment RepositoryFragment on Repository {
        name
      }

      query Query {
        repository {
          ...RepositoryFragment
        }
      }
    GRAPHQL

    response = @client.query(Temp::Queries::Query)
    assert_equal "rails", response.data.repository.name
  end

  def test_supports_unions_with_array_fields
    Temp.const_set :Fragment, @client.parse(<<-'GRAPHQL')
      fragment on IssueOrPullRequest {
        ... on PullRequest {
          assignees {
            login
          }
        }

        ... on Issue {
          assignees {
            login
          }
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        issueOrPullRequest {
          ...TestQueryResult::Temp::Fragment
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)
    obj = Temp::Fragment.new(response.data.issue_or_pull_request)

    assert_equal 1, obj.assignees.size
    assert_equal "josh", obj.assignees[0].login
  end

  def test_parse_invalid_fragment_cast
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

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        repository {
          ...TestQueryResult::Temp::RepositoryFragment
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    repo = Temp::RepositoryFragment.new(response.data.repository)

    assert_equal "rails", repo.name
    assert_equal "josh", repo.owner.login

    assert_raises TypeError,  "TestQueryResult::Temp::UserFragment is not included in TestQueryResult::Temp::RepositoryFragment" do
      Temp::UserFragment.new(repo.owner)
    end
  end

  def test_parse_invalid_fragment_cast_on_spread
    Temp.const_set :AdminFragment, @client.parse(<<-'GRAPHQL')
      fragment on AdminUser {
        password
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        node(id: "1") {
          id
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    assert_raises TypeError, "TestQueryResult::Temp::AdminFragment is not included in TestQueryResult::Temp::Query" do
      Temp::AdminFragment.new(response.data.node)
    end
  end

  def test_parse_valid_fragment_cast_on_spread
    Temp.const_set :AdminFragment, @client.parse(<<-'GRAPHQL')
      fragment on AdminUser {
        password
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        node(id: "1") {
          ...TestQueryResult::Temp::AdminFragment
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)
    admin = Temp::AdminFragment.new(response.data.node)

    assert_equal "secret", admin.password
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

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        node(id: "1") {
          ...TestQueryResult::Temp::UserFragment
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    user = Temp::UserFragment.new(response.data.node)

    assert_equal "1", user.id
    assert_kind_of Array, user.repositories
    assert_equal "github", user.repositories[0].name
    assert_equal "josh", user.repositories[0].watchers[0].login
  end

  def test_client_query_result_with_include_and_skip_directives
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      query($includeId: Boolean!, $skipRepositories: Boolean!) {
        node(id: "1") {
          ... on User {
            id @include(if: $includeId)
            repositories @skip(if: $skipRepositories) {
              name
            }
          }
        }
      }
    GRAPHQL

    assert response = @client.query(Temp::Query, variables: { includeId: true, skipRepositories: false })
    assert user = response.data.node
    assert_equal "1", user.id
    assert_kind_of Array, user.repositories
    assert_equal "github", user.repositories[0].name

    assert response = @client.query(Temp::Query, variables: { includeId: false, skipRepositories: false })
    assert user = response.data.node
    assert_nil user.id
    assert_kind_of Array, user.repositories
    assert_equal "github", user.repositories[0].name

    assert response = @client.query(Temp::Query, variables: { includeId: true, skipRepositories: true })
    assert user = response.data.node
    assert_equal "1", user.id
    assert_nil user.repositories

    assert response = @client.query(Temp::Query, variables: { includeId: false, skipRepositories: true })
    assert user = response.data.node
    assert_nil user.id
    assert_nil user.repositories
  end

  def test_client_query_result_with_type_mismatch
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        node(id: "1") {
          ... on Organization {
            id
          }
        }
      }
    GRAPHQL

    assert response = @client.query(Temp::Query)
    assert user = response.data.node
    assert_kind_of @client.types::User, user
  end
end
