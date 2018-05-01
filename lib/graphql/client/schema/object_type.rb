# frozen_string_literal: true

require "active_support/inflector"
require "graphql/client/error"
require "graphql/client/errors"
require "graphql/client/schema/base_type"
require "graphql/client/schema/possible_types"

module GraphQL
  class Client
    module Schema
      module ObjectType
        def self.new(type, fields = {})
          Class.new(ObjectClass) do
            extend BaseType
            extend ObjectType

            define_singleton_method(:type) { type }
            define_singleton_method(:fields) { fields }
          end
        end

        def define_class(definition, irep_node)
          fields = irep_node.typed_children[type].inject({}) { |h, (field_name, field_irep_node)|
            if definition.indexes[:definitions][field_irep_node.ast_node] == definition.definition_node
              h[field_name.to_sym] = schema_module.define_class(definition, field_irep_node, field_irep_node.definition.type)
            end
            h
          }

          Class.new(self) do
            define_fields(fields)

            if definition.client.enforce_collocated_callers
              keys = fields.keys.map { |key| ActiveSupport::Inflector.underscore(key) }
              Client.enforce_collocated_callers(self, keys, definition.source_location[0])
            end

            class << self
              attr_reader :source_definition
              attr_reader :_spreads
            end

            @source_definition = definition
            @_spreads = definition.indexes[:spreads][irep_node.ast_node]
          end
        end

        def define_fields(fields)
          fields.each { |name, type| define_field(name, type) }
        end

        def define_field(name, type)
          name = name.to_s
          method_name = ActiveSupport::Inflector.underscore(name)

          define_edge_enumeration if name == 'edges'

          define_method(method_name) do
            @casted_data.fetch(name) do
              @casted_data[name] = type.cast(@data[name], @errors.filter_by_path(name))
            end
          end

          define_method("#{method_name}?") do
            @data[name] ? true : false
          end
        end

        # Allows for items.map(&:some_field) rather than
        # items.edges.map(&:node).map(&:some_field).
        def define_edge_enumeration
          self.include(Enumerable)

          define_method(:each) do |&block|
            if block.nil?
              Enumerator.new do |y|
                edges.each { |edge| y << edge.node }
              end
            else
              edges.each { |edge| block.call(edge.node) }
            end
          end
        end

        def cast(value, errors)
          case value
          when Hash
            new(value, errors)
          when NilClass
            nil
          else
            raise InvariantError, "expected value to be a Hash, but was #{value.class}"
          end
        end
      end

      class ObjectClass
        def initialize(data = {}, errors = Errors.new)
          @data = data
          @casted_data = {}
          @errors = errors
        end

        # Public: Returns the raw response data
        #
        # Returns Hash
        def to_h
          @data
        end

        # Public: Return errors associated with data.
        #
        # Returns Errors collection.
        attr_reader :errors

        def method_missing(*args)
          super
        rescue NoMethodError => e
          type = self.class.type

          if ActiveSupport::Inflector.underscore(e.name.to_s) != e.name.to_s
            raise e
          end

          field = type.all_fields.find do |f|
            f.name == e.name.to_s || ActiveSupport::Inflector.underscore(f.name) == e.name.to_s
          end

          unless field
            raise UnimplementedFieldError, "undefined field `#{e.name}' on #{type} type. https://git.io/v1y3m"
          end

          if @data.key?(field.name)
            error_class = ImplicitlyFetchedFieldError
            message = "implicitly fetched field `#{field.name}' on #{type} type. https://git.io/v1yGL"
          else
            error_class = UnfetchedFieldError
            message = "unfetched field `#{field.name}' on #{type} type. https://git.io/v1y3U"
          end

          raise error_class, message
        end

        def inspect
          parent = self.class.ancestors.select { |m| m.is_a?(ObjectType) }.last

          ivars = @data.map { |key, value|
            if value.is_a?(Hash) || value.is_a?(Array)
              "#{key}=..."
            else
              "#{key}=#{value.inspect}"
            end
          }

          buf = "#<#{parent.name}".dup
          buf << " " << ivars.join(" ") if ivars.any?
          buf << ">"
          buf
        end
      end
    end
  end
end
