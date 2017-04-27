# frozen_string_literal: true
require "active_support/inflector"
require "active_support/notifications"
require "graphql"
require "graphql/client/collocated_enforcement"
require "graphql/client/definition"
require "graphql/client/definition_variables"
require "graphql/client/error"
require "graphql/client/errors"
require "graphql/client/fragment_definition"
require "graphql/client/operation_definition"
require "graphql/client/query_result"
require "graphql/client/query_typename"
require "graphql/client/response"
require "graphql/language/nodes/deep_freeze_ext"
require "json"

module GraphQL
  # GraphQL Client helps build and execute queries against a GraphQL backend.
  #
  # A client instance SHOULD be configured with a schema to enable query
  # validation. And SHOULD also be configured with a backend "execute" adapter
  # to point at a remote GraphQL HTTP service or execute directly against a
  # Schema object.
  class Client
    class DynamicQueryError < Error; end
    class NotImplementedError < Error; end
    class ValidationError < Error; end

    extend CollocatedEnforcement

    attr_reader :schema, :execute

    attr_accessor :document_tracking_enabled

    # Public: Check if collocated caller enforcement is enabled.
    attr_reader :enforce_collocated_callers

    # Deprecated: Allow dynamically generated queries to be passed to
    # Client#query.
    #
    # This ability will eventually be removed in future versions.
    attr_accessor :allow_dynamic_queries

    def self.load_schema(schema)
      case schema
      when GraphQL::Schema
        schema
      when Hash
        GraphQL::Schema::Loader.load(schema)
      when String
        if schema.end_with?(".json") && File.exist?(schema)
          load_schema(File.read(schema))
        elsif schema =~ /\A\s*{/
          load_schema(JSON.parse(schema))
        end
      else
        load_schema(dump_schema(schema)) if schema.respond_to?(:execute)
      end
    end

    IntrospectionDocument = GraphQL.parse(GraphQL::Introspection::INTROSPECTION_QUERY).deep_freeze

    def self.dump_schema(schema, io = nil)
      unless schema.respond_to?(:execute)
        raise TypeError, "expected schema to respond to #execute(), but was #{schema.class}"
      end

      result = schema.execute(
        document: IntrospectionDocument,
        operation_name: "IntrospectionQuery",
        variables: {},
        context: {}
      )

      if io
        io = File.open(io, "w") if io.is_a?(String)
        io.write(JSON.pretty_generate(result))
        io.close_write
      end

      result
    end

    def initialize(schema:, execute: nil, enforce_collocated_callers: false)
      @schema = self.class.load_schema(schema)
      @execute = execute
      @document = GraphQL::Language::Nodes::Document.new(definitions: [])
      @document_tracking_enabled = false
      @allow_dynamic_queries = false
      @enforce_collocated_callers = enforce_collocated_callers
    end

    def parse(str, filename = nil, lineno = nil)
      if filename.nil? && lineno.nil?
        location = caller_locations(1, 1).first
        filename = location.path
        lineno = location.lineno
      end

      unless filename.is_a?(String)
        raise TypeError, "expected filename to be a String, but was #{filename.class}"
      end

      unless lineno.is_a?(Integer)
        raise TypeError, "expected lineno to be a Integer, but was #{lineno.class}"
      end

      source_location = [filename, lineno].freeze

      definition_dependencies = Set.new

      str = str.gsub(/\.\.\.([a-zA-Z0-9_]+(::[a-zA-Z0-9_]+)*)/) do
        match = Regexp.last_match
        const_name = match[1]

        if str.match(/fragment\s*#{const_name}/)
          match[0]
        else
          begin
            fragment = ActiveSupport::Inflector.constantize(const_name)
          rescue NameError
            fragment = nil
          end

          case fragment
          when FragmentDefinition
            definition_dependencies.merge(fragment.document.definitions)
            "...#{fragment.definition_name}"
          else
            if fragment
              message = "expected #{const_name} to be a #{FragmentDefinition}, but was a #{fragment.class}."
              if fragment.is_a?(Module) && fragment.constants.any?
                message += " Did you mean #{fragment}::#{fragment.constants.first}?"
              end
            else
              message = "uninitialized constant #{const_name}"
            end

            error = ValidationError.new(message)
            error.set_backtrace(["#{filename}:#{lineno + match.pre_match.count("\n") + 1}"] + caller)
            raise error
          end
        end
      end

      doc = GraphQL.parse(str)

      doc.definitions.each do |node|
        node.name ||= "__anonymous__"
      end

      document_dependencies = Language::Nodes::Document.new(definitions: doc.definitions + definition_dependencies.to_a)

      rules = GraphQL::StaticValidation::ALL_RULES - [
        GraphQL::StaticValidation::FragmentsAreUsed,
        GraphQL::StaticValidation::FieldsHaveAppropriateSelections
      ]
      validator = GraphQL::StaticValidation::Validator.new(schema: self.schema, rules: rules)
      query = GraphQL::Query.new(self.schema, document: document_dependencies)

      errors = validator.validate(query)
      errors.fetch(:errors).each do |error|
        error_hash = error.to_h
        validation_line = error_hash["locations"][0]["line"]
        error = ValidationError.new(error_hash["message"])
        error.set_backtrace(["#{filename}:#{lineno + validation_line}"] + caller)
        raise error
      end

      document_types = DocumentTypes.analyze_types(self.schema, doc).freeze

      QueryTypename.insert_typename_fields(doc, types: document_types)

      definitions = {}
      doc.definitions.each do |node|
        node.name = nil if node.name == "__anonymous__"
        sliced_document = Language::DefinitionSlice.slice(document_dependencies, node.name)
        definition = Definition.for(
          schema: self.schema,
          node: node,
          document: sliced_document,
          document_types: document_types,
          source_location: source_location,
          enforce_collocated_callers: enforce_collocated_callers
        )
        definitions[node.name] = definition
      end

      rename_node = ->(node, _parent) do
        definition = definitions[node.name]
        if definition
          node.extend(LazyName)
          node.name = -> { definition.definition_name }
        end
      end
      visitor = Language::Visitor.new(doc)
      visitor[Language::Nodes::FragmentDefinition].leave << rename_node
      visitor[Language::Nodes::OperationDefinition].leave << rename_node
      visitor[Language::Nodes::FragmentSpread].leave << rename_node
      visitor.visit

      doc.deep_freeze

      document.definitions.concat(doc.definitions) if document_tracking_enabled

      if definitions[nil]
        definitions[nil]
      else
        Module.new do
          definitions.each do |name, definition|
            const_set(name, definition)
          end
        end
      end
    end

    # Public: Create operation definition from a fragment definition.
    #
    # Automatically determines operation variable set.
    #
    # Examples
    #
    #   FooFragment = Client.parse <<-'GRAPHQL'
    #     fragment on Mutation {
    #       updateFoo(id: $id, content: $content)
    #     }
    #   GRAPHQL
    #
    #   # mutation($id: ID!, $content: String!) {
    #   #   updateFoo(id: $id, content: $content)
    #   # }
    #   FooMutation = Client.create_operation(FooFragment)
    #
    # fragment - A FragmentDefinition definition.
    #
    # Returns an OperationDefinition.
    def create_operation(fragment, filename = nil, lineno = nil)
      unless fragment.is_a?(GraphQL::Client::FragmentDefinition)
        raise TypeError, "expected fragment to be a GraphQL::Client::FragmentDefinition, but was #{fragment.class}"
      end

      if filename.nil? && lineno.nil?
        location = caller_locations(1, 1).first
        filename = location.path
        lineno = location.lineno
      end

      variables = GraphQL::Client::DefinitionVariables.operation_variables(self.schema, fragment.document, fragment.definition_name)
      type_name = fragment.definition_node.type.name

      if schema.query && type_name == schema.query.name
        operation_type = "query"
      elsif schema.mutation && type_name == schema.mutation.name
        operation_type = "mutation"
      elsif schema.subscription && type_name == schema.subscription.name
        operation_type = "subscription"
      else
        types = [schema.query, schema.mutation, schema.subscription].compact
        raise Error, "Fragment must be defined on #{types.map(&:name).join(", ")}"
      end

      doc_ast = GraphQL::Language::Nodes::Document.new(definitions: [
        GraphQL::Language::Nodes::OperationDefinition.new(
          operation_type: operation_type,
          variables: variables,
          selections: [
            GraphQL::Language::Nodes::FragmentSpread.new(name: fragment.name)
          ]
        )
      ])
      parse(doc_ast.to_query_string, filename, lineno)
    end

    attr_reader :document

    def query(definition, variables: {}, context: {})
      raise NotImplementedError, "client network execution not configured" unless execute

      unless definition.is_a?(OperationDefinition)
        raise TypeError, "expected definition to be a #{OperationDefinition.name} but was #{document.class.name}"
      end

      if allow_dynamic_queries == false && definition.name.nil?
        raise DynamicQueryError, "expected definition to be assigned to a static constant https://git.io/vXXSE"
      end

      variables = deep_stringify_keys(variables)

      document = definition.document
      operation = definition.definition_node

      payload = {
        document: document,
        operation_name: operation.name,
        operation_type: operation.operation_type,
        variables: variables,
        context: context
      }

      result = ActiveSupport::Notifications.instrument("query.graphql", payload) do
        execute.execute(
          document: document,
          operation_name: operation.name,
          variables: variables,
          context: context
        )
      end

      data, errors, extensions = result.values_at("data", "errors", "extensions")

      errors ||= []
      GraphQL::Client::Errors.normalize_error_paths(data, errors)

      errors.each do |error|
        error_payload = payload.merge(message: error["message"], error: error)
        ActiveSupport::Notifications.instrument("error.graphql", error_payload)
      end

      Response.new(
        data: definition.new(data, Errors.new(errors, ["data"])),
        errors: Errors.new(errors),
        extensions: extensions
      )
    end

    # Internal: FragmentSpread and FragmentDefinition extension to allow its
    # name to point to a lazily defined Proc instead of a static string.
    module LazyName
      def name
        @name.call
      end
    end

    private

    def deep_stringify_keys(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(k, v), h|
          h[k.to_s] = deep_stringify_keys(v)
        end
      else
        obj
      end
    end
  end
end
