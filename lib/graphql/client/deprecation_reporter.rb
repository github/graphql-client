# frozen_string_literal: true

module GraphQL
  class Client
    module DeprecationReporter
      def self.report(qualified_name:, deprecation_reason:, source_file:, line_number:)
        STDERR.puts("GRAPHQL DEPRECATION WARNING: #{qualified_name} is deprecated with reason: "\
          "'#{deprecation_reason}': #{source_file}:#{line_number}")
      end
    end
  end
end
