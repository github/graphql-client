# GraphQL::Client::DynamicQueryError

Raised when trying to execute a query that was not assigned to at static constant.

```ruby
# good
HeroNameQuery = SWAPI::Client.parse <<-'GRAPHQL'
  query($id: ID!) {
    hero(id: $id) {
      name
    }
  }
GRAPHQL
result = SWAPI::Client.query(HeroNameQuery, variables: { id: params[:id] })
```

```ruby
# bad
hero_query = SWAPI::Client.parse <<-'GRAPHQL'
  query($id: ID!) {
    hero(id: $id) {
      name
    }
  }
GRAPHQL
result = SWAPI::Client.query(hero_query, variables: { id: params[:id] })
```

Parsing a query and validating a query on every request adds performance overhead. It also prevents validation errors from being discovered until request time, rather than when the query is parsed at startup.

```ruby
# horrible
hero_query = SWAPI::Client.parse <<-GRAPHQL
  query {
    hero(id: "#{id}") {
      name
    }
  }
GRAPHQL
result = SWAPI::Client.query(hero_query)
```

Building runtime GraphQL query strings with user input may lead to security issues. Always using a static query along with variables is a best practice.
