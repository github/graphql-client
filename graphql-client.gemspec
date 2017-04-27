# frozen_string_literal: true
Gem::Specification.new do |s|
  s.name = "graphql-client"
  s.version = "0.8.6"
  s.summary = "GraphQL Client"
  s.description = "A Ruby library for declaring, composing and executing GraphQL queries"
  s.homepage = "https://github.com/github/graphql-client"
  s.license = "MIT"

  s.files = Dir["README.md", "LICENSE", "lib/**/*.rb"]

  s.add_dependency "activesupport", ">= 3.0", "< 6.0"
  s.add_dependency "graphql", "~> 1.2"

  s.add_development_dependency "actionpack", ">= 3.2.22", "< 6.0"
  s.add_development_dependency "erubi", "~> 1.6"
  s.add_development_dependency "erubis", "~> 2.7"
  s.add_development_dependency "minitest", "~> 5.9"
  s.add_development_dependency "rake", "~> 11.2"
  s.add_development_dependency "rubocop-github", "~> 0.3"
  s.add_development_dependency "rubocop", "~> 0.47"

  s.required_ruby_version = ">= 2.1.0"

  s.email = "engineering@github.com"
  s.authors = "GitHub"
end
