# frozen_string_literal: true
require "graphql"

module GraphQL
  class Client
    # Internal: Use schema to detect definition and field types.
    module DocumentTypes
      # Internal: Detect all types used in a given document
      #
      # schema - A GraphQL::Schema
      # document - A GraphQL::Language::Nodes::Document to scan
      #
      # Returns a Hash[Language::Nodes::Node] to GraphQL::Type objects.
      def self.analyze_types(schema, document)
        unless schema.is_a?(GraphQL::Schema)
          raise TypeError, "expected schema to be a GraphQL::Schema, but was #{schema.class}"
        end

        unless document.is_a?(GraphQL::Language::Nodes::Document)
          raise TypeError, "expected schema to be a GraphQL::Language::Nodes::Document, but was #{document.class}"
        end

        visitor = GraphQL::Language::Visitor.new(document)
        type_stack = GraphQL::StaticValidation::TypeStack.new(schema, visitor)

        fields = {}

        visitor[GraphQL::Language::Nodes::OperationDefinition] << ->(node, _parent) do
          fields[node] = type_stack.object_types.last
        end
        visitor[GraphQL::Language::Nodes::FragmentDefinition] << ->(node, _parent) do
          fields[node] = type_stack.object_types.last
        end
        visitor[GraphQL::Language::Nodes::InlineFragment] << ->(node, _parent) do
          fields[node] = type_stack.object_types.last
        end
        visitor[GraphQL::Language::Nodes::Field] << ->(node, _parent) do
          fields[node] = type_stack.field_definitions.last.type
        end
        visitor.visit

        fields
      end
    end
  end
end
