# frozen_string_literal: true

require "graphql/client/error"
require "graphql/client/schema/base_type"

module GraphQL
  class Client
    module Schema
      class EnumType < Module
        include BaseType

        # Internal: Construct enum wrapper from another GraphQL::EnumType.
        #
        # type - GraphQL::EnumType instance
        def initialize(type)
          unless type.is_a?(GraphQL::EnumType)
            raise "expected type to be a GraphQL::EnumType, but was #{type.class}"
          end

          @type = type
          @values = {}

          all_values = type.values.keys

          all_values.each do |value|
            str = value.dup
            all_values.each do |v|
              str.define_singleton_method("#{v.downcase}?") { false }
            end
            str.define_singleton_method("#{value.downcase}?") { true }
            str.freeze
            const_set(value, str) if value =~ /^[A-Z]/
            @values[str] = str
          end

          @values.freeze
        end

        def define_class(definition, ast_nodes)
          self
        end

        def [](value)
          @values[value]
        end

        # Internal: Cast JSON value to the enumeration's corresponding constant string instance
        #  with the convenience predicate methods.
        #
        # values - JSON value
        # errors - Errors instance
        #
        # Returns String or nil.
        def cast(value, _errors = nil)
          case value
          when String
            raise Error, "unexpected enum value #{value}" unless @values.key?(value)
            @values[value]
          when NilClass
            value
          else
            raise InvariantError, "expected value to be a String, but was #{value.class}"
          end
        end
      end
    end
  end
end
