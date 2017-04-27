# frozen_string_literal: true
require "active_support/inflector"
require "graphql"
require "graphql/client/errors"
require "graphql/client/list"
require "set"

module GraphQL
  class Client
    # A QueryResult struct wraps data returned from a GraphQL response.
    #
    # Wrapping the JSON-like Hash allows access with nice Ruby accessor methods
    # rather than using `obj["key"]` access.
    #
    # Wrappers also limit field visibility to fragment definitions.
    class QueryResult
      class NoFieldError < Error; end
      class ImplicitlyFetchedFieldError < NoFieldError; end
      class UnfetchedFieldError < NoFieldError; end
      class UnimplementedFieldError < NoFieldError; end

      # Internal: Get QueryResult class for result of query.
      #
      # Returns subclass of QueryResult or nil.
      def self.wrap(source_definition, node, type, name: nil)
        case type
        when GraphQL::NonNullType
          NonNullWrapper.new(wrap(source_definition, node, type.of_type, name: name))
        when GraphQL::ListType
          ListWrapper.new(wrap(source_definition, node, type.of_type, name: name))
        when GraphQL::ScalarType
          ScalarWrapper.new(type)
        when GraphQL::EnumType
          EnumWrapper.new(type)
        # when GraphQL::UnionType
        #   types = {}
        #
        #   node.selections.each do |selection|
        #     case selection
        #     when Language::Nodes::InlineFragment
        #       selection_type = source_definition.document_types[selection]
        #       selection_wrapper = wrap(source_definition, selection, selection_type, name: name)
        #       if types[selection_type]
        #         p [:merge, selection_type]
        #         types[selection_type.name] |= selection_wrapper
        #       else
        #         types[selection_type.name] = selection_wrapper
        #       end
        #     end
        #   end
        #
        #   UnionWrapper.new(types)
        when GraphQL::ObjectType, GraphQL::InterfaceType, GraphQL::UnionType
          fields = {}

          node.selections.each do |selection|
            case selection
            when Language::Nodes::FragmentSpread
              nil
            when Language::Nodes::Field
              field_name = selection.alias || selection.name
              selection_type = source_definition.document_types[selection]
              selection_type = GraphQL::STRING_TYPE if field_name == "__typename"
              field_klass = wrap(source_definition, selection, selection_type, name: "#{name}[:#{field_name}]")
              fields[field_name] ? fields[field_name] |= field_klass : fields[field_name] = field_klass
            when Language::Nodes::InlineFragment
              selection_type = source_definition.document_types[selection]
              wrap(source_definition, selection, selection_type, name: name).fields.each do |fragment_name, klass|
                fields[fragment_name.to_s] ? fields[fragment_name.to_s] |= klass : fields[fragment_name.to_s] = klass
              end
            end
          end

          define(name: name, type: type, source_definition: source_definition, source_node: node, fields: fields)
        else
          raise TypeError, "unexpected #{type.class}"
        end
      end

      class UnionWrapper
        def initialize(possible_types)
          @possible_types = possible_types
        end

        def cast(value, errors = nil)
          typename = value && value["__typename"]
          if wrapper = @possible_types[typename]
            wrapper.cast(value, errors)
          else
            raise TypeError, "expected union value to be #{@possible_types.keys.join(", ")}, but was #{typename}"
          end
        end

        def |(_other)
          # XXX: How would union merge?
          self
        end
      end

      class ListWrapper
        attr_reader :of_klass

        def initialize(type)
          @of_klass = type
        end

        def cast(value, errors)
          case value
          when Array
            List.new(value.each_with_index.map { |e, idx|
              @of_klass.cast(e, errors.filter_by_path(idx))
            }, errors)
          when NilClass
            nil
          else
            raise ArgumentError, "expected list value to be an Array, but was #{value.class}"
          end
        end

        def |(other)
          if self.class == other.class
            self.of_klass | other.of_klass
          else
            raise TypeError, "expected other to be a #{self.class}"
          end
        end
      end

      class NonNullWrapper
        attr_reader :of_klass

        def initialize(type)
          @of_klass = type
        end

        def cast(value, errors)
          case value
          when NilClass
            # TODO
            # raise ArgumentError, "expected non-nullable value to be present"
            nil
          else
            @of_klass.cast(value, errors)
          end
        end

        def |(other)
          if self.class == other.class
            self.of_klass | other.of_klass
          else
            raise TypeError, "expected other to be a #{self.class}"
          end
        end
      end

      class EnumWrapper
        def initialize(type)
          @type = type
        end

        def cast(value, _errors = nil)
          value
        end

        def |(_other)
          # XXX: How would enums merge?
          self
        end
      end

      # :nodoc:
      class ScalarWrapper
        def initialize(type)
          @type = type
        end

        def cast(value, _errors = nil)
          if value.is_a? Array
            value.map { |item|
              if @type.respond_to?(:coerce_isolated_input)
                @type.coerce_isolated_input(item)
              else
                @type.coerce_input(item)
              end
            }
          else
            if @type.respond_to?(:coerce_isolated_input)
              @type.coerce_isolated_input(value)
            else
              @type.coerce_input(value)
            end
          end
        end

        def |(_other)
          # XXX: How would scalars merge?
          self
        end
      end

      # Internal
      def self.define(name:, type:, source_definition:, source_node:, fields: {})
        Class.new(self) do
          @name = name
          @type = type
          @source_node = source_node
          @source_definition = source_definition
          @fields = {}

          field_readers = Set.new

          fields.each do |field, klass|
            @fields[field.to_sym] = klass

            send :attr_reader, field
            field_readers << field.to_sym

            # Convert GraphQL camelcase to snake case: commitComments -> commit_comments
            field_alias = ActiveSupport::Inflector.underscore(field)
            send :alias_method, field_alias, field if field != field_alias
            field_readers << field_alias.to_sym

            class_eval <<-RUBY, __FILE__, __LINE__
              def #{field_alias}?
                #{field_alias} ? true : false
              end
            RUBY
            field_readers << "#{field_alias}?".to_sym
          end

          assigns = @fields.map do |field, klass|
            <<-RUBY
              @#{field} = self.class.fields[:#{field}].cast(@data["#{field}"], @errors.filter_by_path("#{field}"))
            RUBY
          end

          if @type.is_a?(GraphQL::ObjectType)
            assigns.unshift "@__typename = self.class.type.name"
          end

          class_eval <<-RUBY, __FILE__, __LINE__
            def initialize(data, errors = Errors.new)
              @data = data
              @errors = errors

              #{assigns.join("\n")}
              freeze
            end
          RUBY

          if @source_definition.enforce_collocated_callers
            Client.enforce_collocated_callers(self, field_readers, source_definition.source_location[0])
          end
        end
      end

      class << self
        attr_reader :type

        attr_reader :source_definition

        attr_reader :source_node

        attr_reader :fields

        def schema
          source_definition.schema
        end

        def [](name)
          fields[name]
        end
      end

      def self.name
        @name || super || GraphQL::Client::QueryResult.name
      end

      def self.inspect
        "#<#{name} fields=#{@fields.keys.inspect}>"
      end

      def self.cast(obj, errors = Errors.new)
        case obj
        when Hash
          new(obj, errors)
        when self
          obj
        when QueryResult
          spreads = Set.new(self.spreads(obj.class.source_node).map(&:name))

          unless spreads.include?(source_node.name)
            raise TypeError, "#{self.source_definition.name} is not included in #{obj.class.source_definition.name}"
          end
          cast(obj.to_h, obj.errors)
        when NilClass
          nil
        else
          raise TypeError, "expected #{obj.inspect} to be a Hash"
        end
      end

      # Internal
      def self.spreads(node)
        node.selections.flat_map do |selection|
          case selection
          when Language::Nodes::FragmentSpread
            selection
          when Language::Nodes::InlineFragment
            spreads(selection)
          else
            []
          end
        end
      end

      def self.new(obj, *args)
        case obj
        when Hash
          super
        else
          cast(obj, *args)
        end
      end

      def self.|(other)
        new_fields = fields.dup
        other.fields.each do |name, value|
          if new_fields[name]
            new_fields[name] |= value
          else
            new_fields[name] = value
          end
        end
        # TODO: Picking first source node seems error prone
        define(name: self.name, type: self.type, source_definition: source_definition, source_node: source_node, fields: new_fields)
      end

      # Public: Return errors associated with data.
      #
      # Returns Errors collection.
      attr_reader :errors

      attr_reader :__typename
      alias typename __typename

      # Public: Returns the raw response data
      #
      # Returns Hash
      def to_h
        @data
      end

      def type_of?(*types)
        types.any? do |type|
          if type = self.class.schema.types.fetch(type.to_s, nil)
            self.class.schema.possible_types(type).any? { |t| @__typename == t.name }
          else
            false
          end
        end
      end

      def inspect
        ivars = self.class.fields.keys.map do |sym|
          value = instance_variable_get("@#{sym}")
          if value.is_a?(QueryResult)
            "#{sym}=#<#{value.class.name}>"
          else
            "#{sym}=#{value.inspect}"
          end
        end
        buf = "#<#{self.class.name}".dup
        buf << " " << ivars.join(" ") if ivars.any?
        buf << ">"
        buf
      end

      def method_missing(*args)
        super
      rescue NoMethodError => e
        type = self.class.type
        raise e unless type

        field = type.all_fields.find do |f|
          f.name == e.name.to_s || ActiveSupport::Inflector.underscore(f.name) == e.name.to_s
        end

        unless field
          raise UnimplementedFieldError, "undefined field `#{e.name}' on #{type} type. https://git.io/v1y3m"
        end

        if @data[field.name]
          error_class = ImplicitlyFetchedFieldError
          message = "implicitly fetched field `#{field.name}' on #{type} type. https://git.io/v1yGL"
        else
          error_class = UnfetchedFieldError
          message = "unfetched field `#{field.name}' on #{type} type. https://git.io/v1y3U"
        end

        node = self.class.source_node
        message += "\n\n" + node.to_query_string.sub(/\}$/, "+ #{field.name}\n}") if node
        raise error_class, message
      end

      def respond_to_missing?(*args)
        super
      end
    end
  end
end
