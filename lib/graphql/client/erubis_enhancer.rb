# frozen_string_literal: true

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
        graphql, _ = GraphQL::Client::ViewModule.extract_graphql_section(input)

        # Get the name of the fragment
        #
        # So `fragment Pat on User` would return "Pat"
        fragment_name = graphql.match(/fragment ([A-Z]\w+) on/).try :[], 1

        # Convert it to a local we'll use
        local_name = fragment_name.underscore

        # Get the namespace
        const_name = @filename.inspect
          .gsub(/^app\//, "")
          .gsub(/\.html\.erb$/, "")
          .camelize

        input = input.gsub /<%graphql/, <<-ERB
        <%
          raise ArgumentError, "This template must be passed `#{local_name}`" unless local_assigns[:#{local_name}]
          #{local_name} = #{const_name}::#{fragment_name}.new(#{local_name})
        %>
        ERB

        super(src, input)
      end
    end
  end
end
