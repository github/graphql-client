# frozen_string_literal: true
require "graphql"
require "graphql/client/deprecation"
require "minitest/autorun"

class TestDeprecation < MiniTest::Test
  def test_warn
    GraphQL::Client::Deprecation.silence do
      GraphQL::Client::Deprecation.warn("test")
    end
  end
end
