# frozen_string_literal: true

require "graphql/client/error"
require "graphql/client/schema/base_type"
require "graphql/client/schema/object_type"

module GraphQL
  class Client
    module Schema
      class PossibleTypes
        include BaseType

        def initialize(type, types)
          @type = type

          unless types.is_a?(Enumerable)
            raise TypeError, "expected types to be Enumerable, but was #{types.class}"
          end

          @possible_types = {}
          types.each do |klass|
            unless klass.is_a?(ObjectType)
              raise TypeError, "expected type to be #{ObjectType}, but was #{type.class}"
            end
            @possible_types[klass.type.name] = klass
          end
        end

        attr_reader :possible_types

        # Internal: Cast JSON value to wrapped value.
        #
        # value - JSON value
        # errors - Errors instance
        #
        # Returns BaseType instance.
        def cast(value, errors)
          case value
          when Hash
            typename = value["__typename"]
            if type = possible_types[typename]
              type.cast(value, errors)
            else
              raise InvariantError, "expected value to be one of (#{possible_types.keys.join(", ")}), but was #{typename.inspect}"
            end
          when NilClass
            nil
          else
            raise InvariantError, "expected value to be a Hash, but was #{value.class}"
          end
        end
      end
    end
  end
end
