# frozen_string_literal: true
require "json"
require "net/http"
require "uri"

module GraphQL
  class Client
    # Public: Basic HTTP network adapter.
    #
    #   GraphQL::Client::Client.new(
    #     execute: GraphQL::Client::HTTP.new("http://graphql-swapi.parseapp.com/")
    #   )
    #
    # Assumes GraphQL endpoint follows the express-graphql endpoint conventions.
    #   https://github.com/graphql/express-graphql#http-usage
    #
    # Production applications should consider implementing there own network
    # adapter. This class exists for trivial stock usage and allows for minimal
    # request header configuration.
    class HTTP
      REDIRECT_LIMIT = 10

      class TooManyRedirectsError < StandardError ; end

      # Public: Create HTTP adapter instance for a single GraphQL endpoint.
      #
      #   GraphQL::Client::HTTP.new("http://graphql-swapi.parseapp.com/") do
      #     def headers(context)
      #       { "User-Agent": "My Client" }
      #     end
      #   end
      #
      # uri - String endpoint URI
      # block - Optional block to configure class
      def initialize(uri, &block)
        @uri = URI.parse(uri)
        singleton_class.class_eval(&block) if block_given?
      end

      # Public: Parsed endpoint URI
      #
      # Returns URI.
      attr_reader :uri

      # Public: Extension point for subclasses to set custom request headers.
      #
      # Returns Hash of String header names and values.
      def headers(_context)
        {}
      end

      # Public: Make an HTTP request for GraphQL query.
      #
      # Implements Client's "execute" adapter interface.
      #
      # document - The Query GraphQL::Language::Nodes::Document
      # operation_name - The String operation definition name
      # variables - Hash of query variables
      # context - An arbitrary Hash of values which you can access
      #
      # Returns { "data" => ... , "errors" => ... } Hash.
      def execute(document:, operation_name: nil, variables: {}, context: {}, uri: nil, redirects: 0)
        if redirects > REDIRECT_LIMIT
          raise TooManyRedirectsError.new("Too many redirects (exceeded #{REDIRECT_LIMIT})")
        end

        uri = uri || @uri
        request = Net::HTTP::Post.new(uri)

        request.basic_auth(uri.user, uri.password) if uri.user || uri.password

        request["Accept"] = "application/json"
        request["Content-Type"] = "application/json"
        headers(context).each { |name, value| request[name] = value }

        body = {}
        body["query"] = document.to_query_string
        body["variables"] = variables if variables.any?
        body["operationName"] = operation_name if operation_name
        request.body = JSON.generate(body)

        response = connection(uri: uri).request(request)

        case response
        when Net::HTTPOK, Net::HTTPBadRequest
          JSON.parse(response.body)
        when Net::HTTPRedirection
          execute(
            document: document,
            operation_name: operation_name,
            variables: variables,
            context: context,
            uri: URI.parse(response["Location"]),
            redirects: redirects + 1
          )
        else
          { "errors" => [{ "message" => "#{response.code} #{response.message}" }] }
        end
      end

      # Public: Extension point for subclasses to customize the Net:HTTP client
      #
      # Returns a Net::HTTP object
      def connection(uri: @uri)
        Net::HTTP.new(uri.host, uri.port).tap do |client|
          client.use_ssl = uri.scheme == "https"
        end
      end
    end
  end
end
