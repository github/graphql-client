# frozen_string_literal: true

require "active_support/inflector"

module GraphQL
  class Client
    # Public: Erubis enhancer that adds support for GraphQL static query sections.
    #
    #   <%graphql
    #     query GetVerison {
    #       version
    #     }
    #   %>
    #   <%= data.version %>
    #
    module ErubisEnhancer
      # Internal: Extend Erubis handler to simply ignore <%graphql sections.
      def convert_input(src, input)
        if @filename
          graphql, _ = GraphQL::Client::ViewModule.extract_graphql_section(input)
          fragments = []

          GraphQL.parse(graphql).definitions.each do |definition|
            next unless definition.class == GraphQL::Language::Nodes::FragmentDefinition

            # Get the name of the fragment
            #
            # So `fragment Pat on User` would return "Pat"
            fragment_name = definition.name

            # Get the local we'll use.
            local_name = ActiveSupport::Inflector.underscore(fragment_name)

            fragments << [fragment_name, local_name]
          end

          # Get the namespace
          const_name = ActiveSupport::Inflector.camelize(@filename
            .gsub(/^app\//, "") # Get rid of app/ prefix
            .gsub(/\.html\.erb$/, "") # Get rid of extension
          )

          inject = fragments.map do |fragment_name, local_name|
            <<-ERB
              raise ArgumentError, "This template must be passed `#{local_name}`" unless local_assigns[:#{local_name}]
              #{local_name} = #{const_name}::#{fragment_name}.new(#{local_name})
            ERB
          end

          input = input.gsub /<%graphql/, <<-ERB
          <%
            #{inject.join("\n")}
          %>
          <%#
          ERB
        else
          input = input.gsub /<%graphql/, "<%#"
        end

        super(src, input)
      end
    end
  end
end
