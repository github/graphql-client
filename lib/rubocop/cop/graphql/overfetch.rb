# frozen_string_literal: true
require "active_support/inflector"
require "graphql"
require "graphql/client/view_module"
require "rubocop"

module RuboCop
  module Cop
    module GraphQL
      # Public: Rubocop for catching overfetched fields in ERB templates.
      class Overfetch < Cop
        def_node_search :send_methods, "({send csend block_pass} ...)"

        def investigate(processed_source)
          erb = File.read(processed_source.buffer.name)
          query, = ::GraphQL::Client::ViewModule.extract_graphql_section(erb)
          return unless query

          aliases = {}
          fields = {}
          ranges = {}

          # TODO: Use GraphQL client parser
          document = ::GraphQL.parse(query.gsub(/::/, "__"))

          visitor = ::GraphQL::Language::Visitor.new(document)
          visitor[::GraphQL::Language::Nodes::Field] << ->(node, _parent) do
            name = node.alias || node.name
            fields[name] ||= 0
            field_aliases(name).each { |n| (aliases[n] ||= []) << name }
            ranges[name] ||= source_range(processed_source.buffer, node.line, 0)
          end
          visitor.visit

          send_methods(processed_source.ast).each do |node|
            method_names = method_names_for(*node)

            method_names.each do |method_name|
              aliases.fetch(method_name, []).each do |field_name|
                fields[field_name] += 1
              end
            end
          end

          fields.each do |field, count|
            next if count > 0
            add_offense(nil, ranges[field], "GraphQL field '#{field}' query but was not used in template.")
          end
        end

        def field_aliases(name)
          names = Set.new

          names << name
          names << "#{name}?"

          names << underscore_name = ActiveSupport::Inflector.underscore(name)
          names << "#{underscore_name}?"

          names
        end

        def method_names_for(*node)
          receiver, method_name, *_args = node
          method_names = []

          method_names << method_name if method_name

          # add field accesses like `nodes.map(&:field)`
          method_names.concat(receiver.children) if receiver && receiver.sym_type?

          method_names.map!(&:to_s)
        end
      end
    end
  end
end
