# Rails Configuration

Checkout the [GitHub GraphQL Rails example application](https://github.com/github/github-graphql-rails-example).

## Setup

Assumes your application is named `Foo`.

### Add graphql-client to your Gemfile

```ruby
gem 'graphql-client'
```

### Configure

First run the initializer:

```
$ rails generate graphql_client:install
```

This will generate the file `config/initializers/graphql-client.rb`. Change this to use a client with your settings.

```ruby
client = GraphQL::Client.new(schema: "db/schema.json", execute: GraphQL::Client::HTTP.new("https://foo.com/"))

config.graphql.client = client

# optional change the location of the views. Defaults to: `app/views`
# Rails.application.config.graphql.client_views_path = Rails.root.join('path/to/views').to_path

```

### Define a schema updater rake task

_(May eventually be part of `graphql/railtie`)_

```ruby
namespace :schema do
  task :update do
    GraphQL::Client.dump_schema(Foo::HTTP, "db/schema.json")
  end
end
```

Its recommended you check in the downloaded schema. Periodically refetch and keep up-to-date.

```sh
$ bin/rake schema:update
$ git add db/schema.json
```
