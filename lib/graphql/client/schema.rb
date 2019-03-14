# frozen_string_literal: true

require "graphql"
require "graphql/client/schema/enum_type"
require "graphql/client/schema/include_directive"
require "graphql/client/schema/interface_type"
require "graphql/client/schema/list_type"
require "graphql/client/schema/non_null_type"
require "graphql/client/schema/object_type"
require "graphql/client/schema/scalar_type"
require "graphql/client/schema/skip_directive"
require "graphql/client/schema/union_type"

module GraphQL
  class Client
    module Schema
      module ClassMethods
        def define_class(definition, ast_nodes, type)
          type_class = case type
          when GraphQL::NonNullType
            define_class(definition, ast_nodes, type.of_type).to_non_null_type
          when GraphQL::ListType
            define_class(definition, ast_nodes, type.of_type).to_list_type
          else
            get_class(type.name).define_class(definition, ast_nodes)
          end

          ast_nodes.each do |ast_node|
            ast_node.directives.each do |directive|
              if directive = self.directives[directive.name.to_sym]
                type_class = directive.new(type_class)
              end
            end
          end

          type_class
        end

        def get_class(type_name)
          const_get(normalize_type_name(type_name))
        end

        def set_class(type_name, klass)
          class_name = normalize_type_name(type_name)

          if constants.include?(class_name.to_sym)
            raise ArgumentError,
              "Can't define #{class_name} to represent type #{type_name} " \
              "because it's already defined"
          end

          const_set(class_name, klass)
        end

        private

        def normalize_type_name(type_name)
          type_name =~ /\A[A-Z]/ ? type_name : type_name.camelize
        end
      end

      def self.generate(schema)
        mod = Module.new
        mod.extend ClassMethods

        mod.define_singleton_method :schema do
          schema
        end

        cache = {}
        schema.types.each do |name, type|
          next if name.start_with?("__")
          if klass = class_for(schema, type, cache)
            klass.schema_module = mod
            mod.set_class(name, klass)
          end
        end

        directives = {}
        mod.define_singleton_method(:directives) { directives }
        directives[:include] = IncludeDirective
        directives[:skip] = SkipDirective

        mod
      end

      def self.class_for(schema, type, cache)
        return cache[type] if cache[type]

        case type
        when GraphQL::InputObjectType
          nil
        when GraphQL::ScalarType
          cache[type] = ScalarType.new(type)
        when GraphQL::EnumType
          cache[type] = EnumType.new(type)
        when GraphQL::ListType
          cache[type] = class_for(schema, type.of_type, cache).to_list_type
        when GraphQL::NonNullType
          cache[type] = class_for(schema, type.of_type, cache).to_non_null_type
        when GraphQL::UnionType
          klass = cache[type] = UnionType.new(type)

          type.possible_types.each do |possible_type|
            possible_klass = class_for(schema, possible_type, cache)
            possible_klass.send :include, klass
          end

          klass
        when GraphQL::InterfaceType
          cache[type] = InterfaceType.new(type)
        when GraphQL::ObjectType
          klass = cache[type] = ObjectType.new(type)

          type.interfaces.each do |interface|
            klass.send :include, class_for(schema, interface, cache)
          end

          type.all_fields.each do |field|
            klass.fields[field.name.to_sym] = class_for(schema, field.type, cache)
          end

          klass
        else
          raise TypeError, "unexpected #{type.class}"
        end
      end
    end
  end
end
