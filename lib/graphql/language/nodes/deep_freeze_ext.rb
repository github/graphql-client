# frozen_string_literal: true
require "graphql"

module GraphQL
  module Language
    module Nodes
      # :nodoc:
      class AbstractNode
        # Public: Freeze entire Node tree
        #
        # Returns self Node.
        def deep_freeze
          scalars # load internal state
          children.each(&:deep_freeze)
          scalars.each { |s| s && s.freeze }
          freeze
          self
        end
      end
    end
  end
end
