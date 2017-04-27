# frozen_string_literal: true
require "active_support/deprecation"

module GraphQL
  class Client
    if ActiveSupport::Deprecation.is_a?(Class)
      Deprecation = ActiveSupport::Deprecation.new("0.9", "graphql-client")
    else
      module Deprecation
        extend self

        def silence(&block)
          ActiveSupport::Deprecation.silence(&block)
        end

        def warn(*args)
          ActiveSupport::Deprecation.warn(*args)
        end

        def deprecate_methods(*args)
          # TODO
        end

        def deprecation_warning(deprecated_method_name, message = nil, caller_backtrace = nil)
          warn "#{deprecated_method_name} is deprecated and will be removed from graphql-client 0.9 (#{message})"
        end
      end
    end
  end
end
