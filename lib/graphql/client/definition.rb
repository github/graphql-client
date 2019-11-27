# frozen_string_literal: true

require "graphql"
require "graphql/client/collocated_enforcement"
require "graphql/client/schema/object_type"
require "graphql/client/schema/possible_types"
require "set"
require "digest"

module GraphQL
  class Client
    # Definitions are constructed by Client.parse and wrap a parsed AST of the
    # query string as well as hold references to any external query definition
    # dependencies.
    #
    # Definitions MUST be assigned to a constant.
    class Definition < Module
      def self.for(ast_node:, **kargs)
        case ast_node
        when Language::Nodes::OperationDefinition
          OperationDefinition.new(ast_node: ast_node, **kargs)
        when Language::Nodes::FragmentDefinition
          FragmentDefinition.new(ast_node: ast_node, **kargs)
        else
          raise TypeError, "expected node to be a definition type, but was #{ast_node.class}"
        end
      end

      def initialize(client:, document:, source_document:, ast_node:, source_location:)
        @client = client
        @document = document
        @source_document = source_document
        @definition_node = ast_node
        @source_location = source_location

        definition_type = case ast_node
        when GraphQL::Language::Nodes::OperationDefinition
          case ast_node.operation_type
          when "mutation"
            @client.schema.mutation
          when "subscription"
            @client.schema.subscription
          when "query", nil
            @client.schema.query
          else
            raise "Unexpected operation_type: #{ast_node.operation_type}"
          end
        when GraphQL::Language::Nodes::FragmentDefinition
          @client.get_type(ast_node.type.name)
        else
          raise "Unexpected ast_node: #{ast_node}"
        end

        @schema_class = client.types.define_class(self, [ast_node], definition_type)

        # Clear cache only needed during initialization
        @indexes = nil
      end

      # Internal: Get associated owner GraphQL::Client instance.
      attr_reader :client

      # Internal root schema class for definition. Returns
      # GraphQL::Client::Schema::ObjectType or
      # GraphQL::Client::Schema::PossibleTypes.
      attr_reader :schema_class

      # Internal: Get underlying operation or fragment definition AST node for
      # definition.
      #
      # Returns OperationDefinition or FragmentDefinition object.
      attr_reader :definition_node

      # Internal: Get original document that created this definition, without
      # any additional dependencies.
      #
      # Returns GraphQL::Language::Nodes::Document.
      attr_reader :source_document

      # Public: Global name of definition in client document.
      #
      # Returns a GraphQL safe name of the Ruby constant String.
      #
      #   "Users::UserQuery" #=> "Users__UserQuery"
      #
      # Returns String.
      def definition_name
        return @definition_name if defined?(@definition_name)

        if name
          @definition_name = name.gsub("::", "__").freeze
        else
          query_body = document.definitions[0].children[0].to_query_string
          digest = Digest::MD5.hexdigest(query_body)
          "#{self.class.name}_#{digest}".gsub("::", "__").freeze
        end
      end

      # Public: Get document with only the definitions needed to perform this
      # operation.
      #
      # Returns GraphQL::Language::Nodes::Document with one OperationDefinition
      # and any FragmentDefinition dependencies.
      attr_reader :document

      # Public: Returns the Ruby source filename and line number containing this
      # definition was not defined in Ruby.
      #
      # Returns Array pair of [String, Fixnum].
      attr_reader :source_location

      def new(obj, errors = Errors.new)
        case schema_class
        when GraphQL::Client::Schema::PossibleTypes
          case obj
          when NilClass
            obj
          else
            cast_object(obj)
          end
        when GraphQL::Client::Schema::ObjectType
          case obj
          when NilClass, schema_class
            obj
          when Hash
            schema_class.new(obj, errors)
          else
            cast_object(obj)
          end
        else
          raise TypeError, "unexpected #{schema_class}"
        end
      end

      # Internal: Nodes AST indexes.
      def indexes
        @indexes ||= begin
          visitor = GraphQL::Language::Visitor.new(document)
          definitions = index_node_definitions(visitor)
          spreads = index_spreads(visitor)
          visitor.visit
          { definitions: definitions, spreads: spreads }
        end
      end

      private

        def cast_object(obj)
          if obj.class.is_a?(GraphQL::Client::Schema::ObjectType)
            unless obj.class._spreads.include?(definition_node.name)
              raise TypeError, "#{definition_node.name} is not included in #{obj.class.source_definition.name}"
            end
            schema_class.cast(obj.to_h, obj.errors)
          else
            raise TypeError, "unexpected #{obj.class}"
          end
        end

        EMPTY_SET = Set.new.freeze

        def index_spreads(visitor)
          spreads = {}
          on_node = ->(node, _parent) do
            node_spreads = flatten_spreads(node).map(&:name)
            spreads[node] = node_spreads.empty? ? EMPTY_SET : Set.new(node_spreads).freeze
          end

          visitor[GraphQL::Language::Nodes::Field] << on_node
          visitor[GraphQL::Language::Nodes::FragmentDefinition] << on_node
          visitor[GraphQL::Language::Nodes::OperationDefinition] << on_node

          spreads
        end

        def flatten_spreads(node)
          spreads = []
          node.selections.each do |selection|
            case selection
            when Language::Nodes::FragmentSpread
              spreads << selection
            when Language::Nodes::InlineFragment
              spreads.concat(flatten_spreads(selection))
            else
              # Do nothing, not a spread
            end
          end
          spreads
        end

        def index_node_definitions(visitor)
          current_definition = nil
          enter_definition = ->(node, _parent) { current_definition = node }
          leave_definition = ->(node, _parent) { current_definition = nil }

          visitor[GraphQL::Language::Nodes::FragmentDefinition].enter << enter_definition
          visitor[GraphQL::Language::Nodes::FragmentDefinition].leave << leave_definition
          visitor[GraphQL::Language::Nodes::OperationDefinition].enter << enter_definition
          visitor[GraphQL::Language::Nodes::OperationDefinition].leave << leave_definition

          definitions = {}
          on_node = ->(node, _parent) { definitions[node] = current_definition }
          visitor[GraphQL::Language::Nodes::Field] << on_node
          visitor[GraphQL::Language::Nodes::FragmentDefinition] << on_node
          visitor[GraphQL::Language::Nodes::InlineFragment] << on_node
          visitor[GraphQL::Language::Nodes::OperationDefinition] << on_node
          definitions
        end
    end
  end
end
