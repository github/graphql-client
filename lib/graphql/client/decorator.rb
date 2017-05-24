# frozen_string_literal: true

module GraphQL
  class Client
    module Decorator
      def self.extended(base)
        base.class_eval do
          @_graphql_client_decorator_module = Module.new
          prepend @_graphql_client_decorator_module
        end
      end

      def decorate_fragment(sym, definitions)
        @_graphql_client_decorator_module.send(:define_method, sym) do |*args, &block|
          args = args.zip(definitions).map { |value, type| type ? type.new(value) : value }
          super(*args, &block)
        end
      end
    end
  end
end
