# frozen_string_literal: true
module GraphQL
  class Client
    # Public: Abstract base class for all errors raised by GraphQL::Client.
    class Error < StandardError
    end

    class InvariantError < Error
    end

    # The Server has returned an error while executing a query
    class QueryError < Error
    end

    class ImplicitlyFetchedFieldError < NoMethodError
    end

    class UnfetchedFieldError < NoMethodError
    end

    class UnimplementedFieldError < NoMethodError
    end
  end
end
