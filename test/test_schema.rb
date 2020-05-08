# frozen_string_literal: true
require "graphql"
require "graphql/client/schema"
require "minitest/autorun"
require "time"

class TestSchemaType < MiniTest::Test
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

  NodeArgInput = GraphQL::InputObjectType.define do
    name "NodeInput"
    argument :id, !types.String
  end

  NodeType = GraphQL::InterfaceType.define do
    name "Node"
    field :id, !types.ID do
      argument :input, NodeArgInput
    end
  end

  PlanEnum = GraphQL::EnumType.define do
    name "Plan"
    value "FREE"
    value "SMALL"
    value "LARGE"
    value "other"
  end

  PersonType = GraphQL::ObjectType.define do
    name "Person"
    interfaces [NodeType]
    field :name, !types.String
    field :firstName, !types.String
    field :lastName, !types.String
    field :age, !types.Int
    field :birthday, !DateTime
    field :friends, !types[!PersonType]
    field :plan, !PlanEnum
  end

  PhotoType = GraphQL::ObjectType.define do
    name "Photo"
    field :height, !types.Int
    field :width, !types.Int
  end

  SearchResultUnion = GraphQL::UnionType.define do
    name "SearchResult"
    possible_types [PersonType, PhotoType]
  end

  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :me, !PersonType
    field :node, NodeType
    field :firstSearchResult, !SearchResultUnion
  end

  Schema = GraphQL::Schema.define(query: QueryType) do
    resolve_type ->(_type, _obj, _ctx) { raise NotImplementedError }
  end

  Types = GraphQL::Client::Schema.generate(Schema)

  def test_query_object_class
    assert_equal QueryType, Types::Query.type
    assert_equal "TestSchemaType::Types::Query", Types::Query.inspect
  end

  def test_person_object_class
    assert Types::Person < Types::Node
    assert Types::Person < Types::SearchResult
    assert_equal PersonType, Types::Person.type
    assert_equal "TestSchemaType::Types::Person", Types::Person.inspect
  end

  def test_photo_object_class
    refute Types::Photo < Types::Node
    assert Types::Photo < Types::SearchResult
    assert_equal PhotoType, Types::Photo.type
    assert_equal "TestSchemaType::Types::Photo", Types::Photo.inspect
  end

  def test_id_scalar_object
    assert_equal GraphQL::ID_TYPE, Types::ID.type
    assert_kind_of GraphQL::Client::Schema::ScalarType, Types::ID
  end

  def test_string_scalar_object
    assert_equal GraphQL::STRING_TYPE, Types::String.type
  end

  def test_int_scalar_object
    assert_equal GraphQL::INT_TYPE, Types::Int.type
  end

  def test_datetime_scalar_object
    assert_equal DateTime, Types::DateTime.type
    assert_equal Time.at(0), Types::DateTime.cast(Time.at(0).iso8601)
  end

  def test_boolean_scalar_object
    assert_equal GraphQL::BOOLEAN_TYPE, Types::Boolean.type
  end

  def test_node_interface_module
    assert_kind_of GraphQL::Client::Schema::InterfaceType, Types::Node
    assert_equal NodeType, Types::Node.type
    assert_equal "TestSchemaType::Types::Node", Types::Node.inspect
  end

  def test_search_result_union
    assert_kind_of GraphQL::Client::Schema::UnionType, Types::SearchResult
    assert_equal SearchResultUnion, Types::SearchResult.type
    assert_equal "TestSchemaType::Types::SearchResult", Types::SearchResult.inspect
  end

  def test_plan_enum_constants
    assert_kind_of GraphQL::Client::Schema::EnumType, Types::Plan
    assert_equal PlanEnum, Types::Plan.type
    assert_equal "TestSchemaType::Types::Plan", Types::Plan.inspect
    assert_equal "FREE", Types::Plan.cast("FREE")

    assert_equal "FREE", Types::Plan::FREE
    assert_equal "SMALL", Types::Plan::SMALL
    assert_equal "LARGE", Types::Plan::LARGE

    assert_equal "FREE", Types::Plan["FREE"]
    assert_equal "SMALL", Types::Plan["SMALL"]
    assert_equal "LARGE", Types::Plan["LARGE"]

    assert Types::Plan::FREE.free?
    refute Types::Plan::FREE.small?
    refute Types::Plan::FREE.large?

    refute Types::Plan::SMALL.free?
    assert Types::Plan::SMALL.small?
    refute Types::Plan::SMALL.large?
  end

  def test_to_non_null_type
    assert non_null_person = Types::Person.to_non_null_type
    assert_kind_of GraphQL::Client::Schema::NonNullType, non_null_person
    assert non_null_person.equal?(Types::Person.to_non_null_type)
    assert non_null_person.to_non_null_type.equal?(Types::Person.to_non_null_type)

    assert non_null_photo = Types::Photo.to_non_null_type
    assert_kind_of GraphQL::Client::Schema::NonNullType, non_null_photo
    assert non_null_photo.equal?(Types::Photo.to_non_null_type)

    refute non_null_photo.equal?(non_null_person)
  end

  def test_to_list_type
    assert person_list = Types::Person.to_list_type
    assert_kind_of GraphQL::Client::Schema::ListType, person_list
    assert person_list.equal?(Types::Person.to_list_type)
    assert person_list.to_list_type.equal?(Types::Person.to_list_type)

    assert photo_list = Types::Photo.to_list_type
    assert_kind_of GraphQL::Client::Schema::ListType, photo_list
    assert photo_list.equal?(Types::Photo.to_list_type)

    refute photo_list.equal?(person_list)
  end

  def test_person_fields
    assert_kind_of GraphQL::Client::Schema::NonNullType, Types::Person.fields[:name]
    assert_equal Types::String, Types::Person.fields[:name].of_klass

    assert_kind_of GraphQL::Client::Schema::NonNullType, Types::Person.fields[:friends]
    assert_kind_of GraphQL::Client::Schema::ListType, Types::Person.fields[:friends].of_klass
    assert_kind_of GraphQL::Client::Schema::NonNullType, Types::Person.fields[:friends].of_klass.of_klass
    assert_kind_of GraphQL::Client::Schema::ObjectType, Types::Person.fields[:friends].of_klass.of_klass.of_klass
    assert_equal Types::Person, Types::Person.fields[:friends].of_klass.of_klass.of_klass

    assert_kind_of GraphQL::Client::Schema::NonNullType, Types::Person.fields[:id]
    assert_equal Types::ID, Types::Person.fields[:id].of_klass
  end

  def test_query_object_subclass
    query_klass = Class.new(Types::Query)
    person_klass = Class.new(Types::Person)

    assert_equal QueryType, query_klass.type
    assert_equal PersonType, person_klass.type

    query_klass.define_field :me, person_klass
    assert_includes query_klass.instance_methods, :me

    person_klass.define_field :id, Types::Person.fields[:id]
    assert_includes person_klass.instance_methods, :id

    assert query = query_klass.new({
      "me" => {
        "id" => "1"
      }
    })

    assert_kind_of Types::Person, query.me
    assert_kind_of person_klass, query.me
    assert_equal "1", query.me.id

    assert_match "#<TestSchemaType::Types::Query", query.inspect

    assert_raises NoMethodError do
      query.todo
    end
  end

  def test_person_object_subclass
    friend_klass = Class.new(Types::Person)
    friend_klass.define_field :id, Types::Person.fields[:id]
    friend_klass.define_field :name, Types::Person.fields[:name]

    person_klass = Class.new(Types::Person)

    person_klass.define_field :id, Types::Person.fields[:id]
    person_klass.define_field :name, Types::Person.fields[:name]
    person_klass.define_field :firstName, Types::Person.fields[:firstName]
    person_klass.define_field :lastName, Types::Person.fields[:lastName]
    person_klass.define_field :birthday, Types::Person.fields[:birthday]
    person_klass.define_field :plan, Types::Person.fields[:plan]
    person_klass.define_field :friends, GraphQL::Client::Schema::NonNullType.new(
      GraphQL::Client::Schema::ListType.new(
        GraphQL::Client::Schema::NonNullType.new(
          friend_klass)))

    assert_includes person_klass.instance_methods, :id
    assert_includes person_klass.instance_methods, :name
    assert_includes person_klass.instance_methods, :first_name
    assert_includes person_klass.instance_methods, :last_name
    assert_includes person_klass.instance_methods, :plan

    assert person = person_klass.new({
      "id" => "1",
      "name" => "Josh",
      "firstName" => "Joshua",
      "lastName" => "Peek",
      "birthday" => Time.at(0).iso8601,
      "plan" => "FREE",
      "friends" => [{
        "id" => "2",
        "name" => "David"
      }]
    })

    assert_kind_of person_klass, person
    assert_kind_of Types::Person, person
    assert_kind_of Types::Node, person

    refute person.errors.any?

    assert_equal "1", person.id
    assert_equal "Josh", person.name
    assert_equal true, person.name?
    assert_equal "Joshua", person.first_name
    assert_equal "Peek", person.last_name
    assert_equal Time.at(0), person.birthday
    assert_equal true, person.plan.free?
    assert_equal 1, person.friends.length
    assert_equal "2", person.friends[0].id
    assert_equal "David", person.friends[0].name

    assert_same Types::Plan::FREE, person.plan

    assert_equal({
      "id" => "1",
      "name" => "Josh",
      "firstName" => "Joshua",
      "lastName" => "Peek",
      "birthday" => Time.at(0).iso8601,
      "plan" => "FREE",
      "friends" => [{
        "id" => "2",
        "name" => "David"
      }]
    }, person.to_h)

    assert_match "#<TestSchemaType::Types::Person", person.inspect

    assert_raises NoMethodError do
      person.age
    end

    refute person.respond_to?(:missing)

    assert_equal "Person", person.class.type.name

    assert person.is_a?(Types::Person)
    assert person.is_a?(Types::Node)
    refute person.is_a?(Types::Photo)

    assert_equal "Joshua", person.first_name
  end

  def test_transform_lowercase_type_name
    person_type = GraphQL::ObjectType.define do
      name "person"
      field :name, types.String
    end

    photo_type = GraphQL::ObjectType.define do
      name "photo"
      field :name, types.String
    end

    search_result_union = GraphQL::UnionType.define do
      name "search_result"
      possible_types [person_type, photo_type]
    end

    query_type = GraphQL::ObjectType.define do
      name "query"
      field :me, !person_type
      field :first_search_result, !search_result_union
    end

    schema = GraphQL::Schema.define(query: query_type) do
      resolve_type ->(_type, _obj, _ctx) { raise NotImplementedError }
    end

    types = GraphQL::Client::Schema.generate(schema)

    assert_equal person_type, types::Person.type
    assert_equal photo_type, types::Photo.type
    assert_equal search_result_union, types::SearchResult.type
  end

  def test_reject_colliding_type_names
    underscored_type = GraphQL::ObjectType.define do
      name "search_result"
      field :id, types.ID
    end

    camelcase_type = GraphQL::ObjectType.define do
      name "SearchResult"
      field :id, types.ID
    end

    query_type = GraphQL::ObjectType.define do
      name "query"
      field :result, !underscored_type
      field :other_result, !camelcase_type
    end

    schema = GraphQL::Schema.define(query: query_type) do
      resolve_type ->(_type, _obj, _ctx) { raise NotImplementedError }
    end

    assert_raises ArgumentError do
      GraphQL::Client::Schema.generate(schema)
    end
  end

  def test_interface_cast
    query_klass = Class.new(Types::Query)
    person_klass = Class.new(Types::Person)
    node_klass = Types::Node.new([person_klass])

    assert_equal NodeType, node_klass.type

    query_klass.define_field :node, node_klass
    assert_includes query_klass.instance_methods, :node

    person_klass.define_field :id, Types::Person.fields[:id]
    assert_includes person_klass.instance_methods, :id

    assert query = query_klass.new({
      "node" => {
        "__typename" => "Person",
        "id" => "1"
      }
    })

    assert_kind_of Types::Node, query.node
    assert_kind_of Types::Person, query.node
    assert_kind_of person_klass, query.node
    assert_equal "1", query.node.id
  end

  def test_union_cast
    query_klass = Class.new(Types::Query)
    person_klass = Class.new(Types::Person)
    search_result_klass = Types::SearchResult.new([person_klass])

    assert_equal SearchResultUnion, search_result_klass.type

    query_klass.define_field :firstSearchResult, search_result_klass
    assert_includes query_klass.instance_methods, :first_search_result

    person_klass.define_field :id, Types::Person.fields[:id]
    assert_includes person_klass.instance_methods, :id

    assert query = query_klass.new({
      "firstSearchResult" => {
        "__typename" => "Person",
        "id" => "1"
      }
    })

    assert_kind_of Types::Person, query.first_search_result
    assert_kind_of person_klass, query.first_search_result
    assert_equal "1", query.first_search_result.id
  end

  def test_skip_directive
    assert klass = Types.directives[:skip]
    assert maybe_plan = klass.new(Types::Plan)

    assert_nil maybe_plan.cast(nil, nil)
    assert_equal Types::Plan::FREE, maybe_plan.cast("FREE", nil)
  end

  def test_include_directive
    assert klass = Types.directives[:include]
    assert maybe_plan = klass.new(Types::Plan)

    assert_nil maybe_plan.cast(nil, nil)
    assert_equal Types::Plan::FREE, maybe_plan.cast("FREE", nil)
  end
end
