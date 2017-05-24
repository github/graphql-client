# frozen_string_literal: true
require "erubis"
require "graphql"
require "graphql/client/erubis_enhancer"
require "graphql/client/erubis"
require "graphql/client/view_module"
require "minitest/autorun"

class TestMagicCasting < MiniTest::Test
  class ErubiEngine < Erubi::Engine
    include GraphQL::Client::ErubiEnhancer
  end

  Root = File.expand_path("..", __FILE__)

  UserType = GraphQL::ObjectType.define do
    name "User"
    field :login, !types.String
    field :birthday, types.String
  end

  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :viewer, !UserType do
      resolve -> (_obj, _args, _ctx) do
        OpenStruct.new(login: "nakajima", birthday: "Today")
      end
    end
  end

  Schema = GraphQL::Schema.define(query: QueryType) do
    resolve_type ->(_obj, _ctx) { raise NotImplementedError }
  end

  Client = GraphQL::Client.new(schema: Schema)

  module Views
    extend GraphQL::Client::ViewModule
    self.path = "#{Root}/views"
    self.client = Client
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

  def test_automatic_casting
    Views.client = @client

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      query {
        viewer {
          ...TestMagicCasting::Views::Users::Casting::Me
          ...TestMagicCasting::Views::Users::Casting::You
        }
      }
    GRAPHQL

    me = @client.query(Temp::Query).data.viewer
    you = @client.query(Temp::Query).data.viewer

    local_assigns = { me: me, you: you }

    filename = "views/users/_casting.html.erb"
    src = File.read(File.join(Root, filename))

    erubis = GraphQL::Client::Erubis.new(src, filename: filename)
    output_buffer = ActionView::OutputBuffer.new
    erubis.result(binding)

    expected = <<-RESULT
      nakajima
      TestMagicCasting::Views::Users::Casting::Me.type
      Today
      TestMagicCasting::Views::Users::Casting::You.type
    RESULT

    assert_equal expected.gsub(/^      /, "").chomp, output_buffer.strip
  end
end
