# frozen_string_literal: true
source "https://rubygems.org"
gemspec

rails_version = ENV["RAILS_VERSION"] == "edge" ? { github: "rails/rails" } : ENV["RAILS_VERSION"]
gem "actionpack", rails_version
gem "activesupport", rails_version

graphql_version = ENV["GRAPHQL_VERSION"] == "1.10-dev" ? { github: "rmosolgo/graphql-ruby", branch: "1.10-dev" } : ENV["GRAPHQL_VERSION"]
if graphql_version
  gem "graphql", graphql_version
end


group :development, :test do
  gem "rubocop", "~> 0.62.0"
end
