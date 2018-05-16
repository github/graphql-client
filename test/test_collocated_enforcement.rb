# frozen_string_literal: true
require "test_helper"

class TestCollocatedEnforcement < MiniTest::Test
  include FooHelper

  class Person
    extend GraphQL::Client::CollocatedEnforcement

    def name
      "Josh"
    end

    def company
      "GitHub"
    end

    def company?
      true
    end

    enforce_collocated_callers(self, %w(name company company?), __FILE__)
  end

  def test_enforce_collocated_callers
    person = Person.new

    assert_equal "Josh", person.name
    assert_equal "GitHub", person.company
    assert_equal true, person.company?
    assert_equal "Josh", person.public_send(:name)

    GraphQL::Client.allow_noncollocated_callers do
      assert_equal "Josh works at GitHub", format_person_info(person)
    end

    assert_raises GraphQL::Client::NonCollocatedCallerError do
      format_person_info(person)
    end

    GraphQL::Client.allow_noncollocated_callers do
      assert_equal true, person_employed?(person)
    end

    assert_raises GraphQL::Client::NonCollocatedCallerError do
      person_employed?(person)
    end

    GraphQL::Client.allow_noncollocated_callers do
      assert_equal "Josh works at GitHub", format_person_info_via_send(person)
    end

    assert_raises GraphQL::Client::NonCollocatedCallerError do
      format_person_info_via_send(person)
    end
  end

  def test_exception_backtrace_excludes_enforce_collocated_callers
    person = Person.new
    begin
      format_person_info(person)
    rescue GraphQL::Client::NonCollocatedCallerError => e
      exception = e
    end

    assert_includes exception.backtrace[0], "in `format_person_info'"
    assert_includes exception.backtrace[1], "in `test_exception_backtrace_excludes_enforce_collocated_callers'"
  end
end
