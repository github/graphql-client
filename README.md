# graphql-client [![Gem Version](https://badge.fury.io/rb/graphql-client.svg)](https://badge.fury.io/rb/graphql-client) [![CI](https://github.com/github/graphql-client/workflows/CI/badge.svg)](https://github.com/github/graphql-client/actions?query=workflow)

GraphQL Client is a Ruby library for declaring, composing and executing GraphQL queries.

## Usage

### Installation

Add `graphql-client` to your Gemfile and then run `bundle install`.

```ruby
# Gemfile
gem 'graphql-client'
```

### Configuration

Sample configuration for a GraphQL Client to query from the [SWAPI GraphQL Wrapper](https://github.com/graphql/swapi-graphql).

```ruby
require "graphql/client"
require "graphql/client/http"

# Star Wars API example wrapper
module SWAPI
  # Configure GraphQL endpoint using the basic HTTP network adapter.
  HTTP = GraphQL::Client::HTTP.new("https://example.com/graphql") do
    def headers(context)
      # Optionally set any HTTP headers
      { "User-Agent": "My Client" }
    end
  end  

  # Fetch latest schema on init, this will make a network request
  Schema = GraphQL::Client.load_schema(HTTP)

  # However, it's smart to dump this to a JSON file and load from disk
  #
  # Run it from a script or rake task
  #   GraphQL::Client.dump_schema(SWAPI::HTTP, "path/to/schema.json")
  #
  # Schema = GraphQL::Client.load_schema("path/to/schema.json")

  Client = GraphQL::Client.new(schema: Schema, execute: HTTP)
end
```

### Defining Queries

If you haven't already, [familiarize yourself with the GraphQL query syntax](http://graphql.org/docs/queries/). Queries are declared with the same syntax inside of a `<<-'GRAPHQL'` heredoc. There isn't any special query builder Ruby DSL.

This client library encourages all GraphQL queries to be declared statically and assigned to a Ruby constant.

```ruby
HeroNameQuery = SWAPI::Client.parse <<-'GRAPHQL'
  query {
    hero {
      name
    }
  }
GRAPHQL
```

Queries can reference variables that are passed in at query execution time.

```ruby
HeroFromEpisodeQuery = SWAPI::Client.parse <<-'GRAPHQL'
  query($episode: Episode) {
    hero(episode: $episode) {
      name
    }
  }
GRAPHQL
```

Fragments are declared similarly.

```ruby
HumanFragment = SWAPI::Client.parse <<-'GRAPHQL'
  fragment on Human {
    name
    homePlanet
  }
GRAPHQL
```

To include a fragment in a query, reference the fragment by constant.

```ruby
HeroNameQuery = SWAPI::Client.parse <<-'GRAPHQL'
  {
    luke: human(id: "1000") {
      ...HumanFragment
    }
    leia: human(id: "1003") {
      ...HumanFragment
    }
  }
GRAPHQL
```

This works for namespaced constants.

```ruby
module Hero
  Query = SWAPI::Client.parse <<-'GRAPHQL'
    {
      luke: human(id: "1000") {
        ...Human::Fragment
      }
      leia: human(id: "1003") {
        ...Human::Fragment
      }
    }
  GRAPHQL
end
```

`::` is invalid in regular GraphQL syntax, but `#parse` makes an initial pass on the query string and resolves all the fragment spreads with [`constantize`](http://api.rubyonrails.org/classes/ActiveSupport/Inflector.html#method-i-constantize).

### Executing queries

Pass the reference of a parsed query definition to `GraphQL::Client#query`. Data is returned back in a wrapped `GraphQL::Client::Schema::ObjectType` struct that provides Ruby-ish accessors.

```ruby
result = SWAPI::Client.query(Hero::Query)

# The raw data is Hash of JSON values
# result["data"]["luke"]["homePlanet"]

# The wrapped result allows to you access data with Ruby methods
result.data.luke.home_planet
```

Client specific execution extras can be retrieved.

```ruby
result = SWAPI::Client.query(Hero::Query)

result.client_extras.response
result.client_extras.response.headers
```

`GraphQL::Client#query` also accepts variables and context parameters that can be leveraged by the underlying network executor.

```ruby
result = SWAPI::Client.query(Hero::HeroFromEpisodeQuery, variables: {episode: "JEDI"}, context: {user_id: current_user_id})
```

### Rails ERB integration

If you're using Ruby on Rails ERB templates, theres a ERB extension that allows static queries to be defined in the template itself.

In standard Ruby you can simply assign queries and fragments to constants and they'll be available throughout the app. However, the contents of an ERB template is compiled into a Ruby method, and methods can't assign constants. So a new ERB tag was extended to declare static sections that include a GraphQL query.

```erb
<%# app/views/humans/human.html.erb %>
<%graphql
  fragment HumanFragment on Human {
    name
    homePlanet
  }
%>

<p><%= human.name %> lives on <%= human.home_planet %>.</p>
```

These `<%graphql` sections are simply ignored at runtime but make their definitions available through constants. The module namespacing is derived from the `.erb`'s path plus the definition name.

```
>> "views/humans/human".camelize
=> "Views::Humans::Human"
>> Views::Humans::Human::HumanFragment
=> #<GraphQL::Client::FragmentDefinition>
```

## Examples

[github/github-graphql-rails-example](https://github.com/github/github-graphql-rails-example) is an example application using this library to implement views on the GitHub GraphQL API.

## Installation

Add `graphql-client` to your app's Gemfile:

```ruby
gem 'graphql-client'
```

## See Also

* [graphql-ruby](https://github.com/rmosolgo/graphql-ruby) gem which implements 80% of what this library provides. ❤️ [@rmosolgo](https://github.com/rmosolgo)
* [Facebook's GraphQL homepage](http://graphql.org/)
* [Facebook's Relay homepage](https://facebook.github.io/relay/)
