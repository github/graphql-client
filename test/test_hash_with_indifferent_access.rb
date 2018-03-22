# frozen_string_literal: true
require "test_helper"

class TestHashWithIndifferentAccess < MiniTest::Test
  def test_string_access
    hash = GraphQL::Client::HashWithIndifferentAccess.new("foo" => 42)
    assert_equal 42, hash["foo"]
    assert_equal 42, hash.fetch("foo")
    assert hash.key?("foo")
  end

  def test_symbol_access
    hash = GraphQL::Client::HashWithIndifferentAccess.new("foo" => 42)
    assert_equal 42, hash[:foo]
    assert_equal 42, hash.fetch(:foo)
    assert hash.key?(:foo)
  end

  def test_snakecase_access
    hash = GraphQL::Client::HashWithIndifferentAccess.new("HashWithIndifferentAccess" => 42)
    assert_equal 42, hash["hash_with_indifferent_access"]
    assert_equal 42, hash.fetch("hash_with_indifferent_access")
    assert hash.key?("hash_with_indifferent_access")
  end

  def test_integer_access
    hash = GraphQL::Client::HashWithIndifferentAccess.new(42 => "foo")
    assert_equal "foo", hash[42]
    assert_equal "foo", hash.fetch(42)
    assert hash.key?(42)
  end

  def test_keys
    hash = GraphQL::Client::HashWithIndifferentAccess.new("foo" => 42)
    assert_equal ["foo"], hash.keys
  end

  def test_values
    hash = GraphQL::Client::HashWithIndifferentAccess.new("foo" => 42)
    assert_equal [42], hash.values
  end

  def test_enumerable_any
    hash = GraphQL::Client::HashWithIndifferentAccess.new("foo" => 42)
    assert hash.any? { |k, _v| k == "foo" }
    refute hash.any? { |k, _v| k == "bar" }
  end

  def test_empty
    hash = GraphQL::Client::HashWithIndifferentAccess.new
    assert hash.empty?

    hash = GraphQL::Client::HashWithIndifferentAccess.new("foo" => 42)
    refute hash.empty?
  end

  def test_length
    hash = GraphQL::Client::HashWithIndifferentAccess.new
    assert_equal 0, hash.length

    hash = GraphQL::Client::HashWithIndifferentAccess.new("foo" => 42)
    assert_equal 1, hash.length
  end

  def test_size
    hash = GraphQL::Client::HashWithIndifferentAccess.new
    assert_equal 0, hash.size

    hash = GraphQL::Client::HashWithIndifferentAccess.new("foo" => 42)
    assert_equal 1, hash.size
  end

  def test_inspect
    hash = GraphQL::Client::HashWithIndifferentAccess.new("foo" => 42)
    assert_equal hash.to_h.inspect, hash.inspect
  end
end
