# frozen_string_literal: true

require "graphql/client/schema/possible_types"

module GraphQL
  class Client
    module Schema
      class UnionType < Module
        include BaseType

        def initialize(type)
          unless type.is_a?(GraphQL::UnionType)
            raise "expected type to be a GraphQL::UnionType, but was #{type.class}"
          end

          @type = type
        end

        def new(types)
          PossibleTypes.new(type, types)
        end

        def define_class(definition, ast_nodes)
          possible_type_names = definition.client.schema.possible_types(type).map(&:graphql_name)
          possible_types = possible_type_names.map { |concrete_type_name|
            schema_module.get_class(concrete_type_name).define_class(definition, ast_nodes)
          }
          new(possible_types)
        end
      end
    end
  end
end
