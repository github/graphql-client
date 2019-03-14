# frozen_string_literal: true
require "graphql"
require "graphql/client/document_types"

module GraphQL
  class Client
    # Internal: Insert __typename field selections into query.
    module QueryTypename
      # Internal: Insert __typename field selections into query.
      #
      # Skips known types when schema is provided.
      #
      # document - GraphQL::Language::Nodes::Document to modify
      # schema - Optional Map of GraphQL::Language::Nodes::Node to GraphQL::Type
      #
      # Returns the document with `__typename` added to it
      if GraphQL::Language::Nodes::AbstractNode.method_defined?(:merge)
        # GraphQL 1.9 introduces a new visitor class
        # and doesn't expose writer methods for node attributes.
        # So, use the node mutation API instead.
        class InsertTypenameVisitor < GraphQL::Language::Visitor
          def initialize(document, types:)
            @types = types
            super(document)
          end

          def add_typename(node, parent)
            type = @types[node]
            type = type && type.unwrap

            if (node.selections.any? && (type.nil? || type.is_a?(GraphQL::InterfaceType) || type.is_a?(GraphQL::UnionType))) ||
              (node.selections.none? && type.is_a?(GraphQL::ObjectType))
              names = QueryTypename.node_flatten_selections(node.selections).map { |s| s.respond_to?(:name) ? s.name : nil }
              names = Set.new(names.compact)

              if names.include?("__typename")
                yield(node, parent)
              else
                node_with_typename = node.merge(selections: [GraphQL::Language::Nodes::Field.new(name: "__typename")] + node.selections)
                yield(node_with_typename, parent)
              end
            else
              yield(node, parent)
            end
          end

          def on_operation_definition(node, parent)
            add_typename(node, parent) { |n, p| super(n, p) }
          end

          def on_field(node, parent)
            add_typename(node, parent) { |n, p| super(n, p) }
          end

          def on_fragment_definition(node, parent)
            add_typename(node, parent) { |n, p| super(n, p) }
          end
        end

        def self.insert_typename_fields(document, types: {})
          visitor = InsertTypenameVisitor.new(document, types: types)
          visitor.visit
          visitor.result
        end

      else
        def self.insert_typename_fields(document, types: {})
          on_selections = ->(node, _parent) do
            type = types[node]

            if node.selections.any?
              case type && type.unwrap
              when NilClass, GraphQL::InterfaceType, GraphQL::UnionType
                names = node_flatten_selections(node.selections).map { |s| s.respond_to?(:name) ? s.name : nil }
                names = Set.new(names.compact)

                unless names.include?("__typename")
                  node.selections = [GraphQL::Language::Nodes::Field.new(name: "__typename")] + node.selections
                end
              end
            elsif type && type.unwrap.is_a?(GraphQL::ObjectType)
              node.selections = [GraphQL::Language::Nodes::Field.new(name: "__typename")]
            end
          end

          visitor = GraphQL::Language::Visitor.new(document)
          visitor[GraphQL::Language::Nodes::Field].leave << on_selections
          visitor[GraphQL::Language::Nodes::FragmentDefinition].leave << on_selections
          visitor[GraphQL::Language::Nodes::OperationDefinition].leave << on_selections
          visitor.visit

          document
        end
      end

      def self.node_flatten_selections(selections)
        selections.flat_map do |selection|
          case selection
          when GraphQL::Language::Nodes::Field
            selection
          when GraphQL::Language::Nodes::InlineFragment
            node_flatten_selections(selection.selections)
          else
            []
          end
        end
      end
    end
  end
end
