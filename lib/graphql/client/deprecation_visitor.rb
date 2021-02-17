# frozen_string_literal: true

require "graphql/client/deprecation_reporter"

module GraphQL
  class Client
    class DeprecationVisitor < GraphQL::Language::Visitor
      def initialize(document:, schema:, source_file:, line_number:)
        super(document)
        @schema = schema
        @source_file = source_file
        @line_number = line_number
        @object_types = []
        @argument_owners = []
      end

      def on_operation_definition(node, parent)
        object_type = @schema.root_type_for_operation(node.operation_type)
        @object_types.push(object_type)
        super
        @object_types.pop
      end

      def on_fragment_definition(node, parent)
        object_type = find_type(node.type.name)
        @object_types.push(object_type)
        super
        @object_types.pop
      end

      def on_inline_fragment(node, parent)
        object_type = find_type(node.type.name)
        @object_types.push(object_type)
        super
        @object_types.pop
      end

      def on_directive(node, parent)
        directive_type = find_directive(node.name)
        @argument_owners.push(directive_type)
        super
        @argument_owners.pop
      end

      def on_field(node, parent)
        parent_type = @object_types.last
        field = @schema.get_field(parent_type.graphql_name, node.name)
        @argument_owners.push(field)
        @object_types.push(field.type.unwrap)

        if field.deprecation_reason
          DeprecationReporter.report(
            qualified_name: "#{parent_type.graphql_name}.#{field.graphql_name}",
            deprecation_reason: field.deprecation_reason,
            source_file: @source_file,
            line_number: @line_number + node.line
          )
        end

        super

        @object_types.pop
        @argument_owners.pop
      end

      def on_argument(node, parent)
        argument_type = arguments_for(@argument_owners.last).fetch(node.name).type.unwrap
        if argument_type.kind.input_object?
          @argument_owners.push(argument_type)
          super
          @argument_owners.pop
        else
          super
        end
      end

      def on_enum(node, parent)
        enum_type = @argument_owners.last.arguments.fetch(parent.name).type.unwrap
        enum_value = enum_values_for(enum_type).fetch(node.name)
        if enum_value && enum_value.deprecation_reason
          DeprecationReporter.report(
            qualified_name: "#{enum_type.graphql_name}.#{enum_value.graphql_name}",
            deprecation_reason: enum_value.deprecation_reason,
            source_file: @source_file,
            line_number: @line_number + node.line
          )
        end

        super
      end

      private

      def find_type(name)
        # For graphql 1.10+
        if @schema.respond_to?(:get_type)
          @schema.get_type(name)
        else
          @type_cache ||= @schema.types
          @type_cache.fetch(name)
        end
      end

      def find_directive(name)
        @directive_cache ||= @schema.directives
        @directive_cache.fetch(name)
      end

      def arguments_for(owner)
        arguments_cache[owner]
      end

      def arguments_cache
        @arguments_cache ||= Hash.new do |cache, owner|
          cache[owner] = owner.arguments
        end
      end

      def enum_values_for(enum)
        enum_values_cache[enum]
      end

      def enum_values_cache
        @enum_values_cache ||= Hash.new do |cache, enum|
          cache[enum] = enum.values
        end
      end
    end
  end
end
