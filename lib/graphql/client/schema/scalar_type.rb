# frozen_string_literal: true

require "graphql/client/schema/base_type"

module GraphQL
  class Client
    module Schema
      class ScalarType
        include BaseType

        # Internal: Construct type wrapper from another GraphQL::BaseType.
        #
        # type - GraphQL::BaseType instance
        def initialize(type)
          unless type.is_a?(GraphQL::ScalarType)
            raise "expected type to be a GraphQL::ScalarType, but was #{type.class}"
          end

          @type = type
        end

        def define_class(definition, ast_nodes)
          self
        end

        # Internal: Cast raw JSON value to Ruby scalar object.
        #
        # value - JSON value
        # errors - Errors instance
        #
        # Returns casted Object.
        def cast(value, _errors = nil)
          case value
          when NilClass
            nil
          else
            if type.respond_to?(:coerce_isolated_input)
              type.coerce_isolated_input(value)
            else
              type.coerce_input(value)
            end
          end
        end
      end
    end
  end
end
