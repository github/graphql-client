# frozen_string_literal: true
require "json"
require "net/http"
require "uri"

module GraphQL
  class Client
    # Public: Basic HTTP network adapter.
    #
    #   GraphQL::Client.new(
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
      def execute(document:, operation_name: nil, variables: {}, context: {})
        request = Net::HTTP::Post.new(uri.request_uri)

        request.basic_auth(uri.user, uri.password) if uri.user || uri.password

        request["Accept"] = "application/json"
        request["Content-Type"] = "application/json"
        headers(context).each { |name, value| request[name] = value }

        form_fields = form_data!(variables)
        body = {}
        body["query"] = document.to_query_string
        body["variables"] = variables if variables.any?
        body["operationName"] = operation_name if operation_name

        if form_fields
          # post as multipart/form-data to stream file contents
          form_fields.append(["operations", JSON.generate(body)])
          request.set_form(form_fields, "multipart/form-data")
        else
          # post as application/json
          request["Content-Type"] = "application/json"
          request.body = JSON.generate(body)
        end

        response = connection.request(request)
        case response
        when Net::HTTPOK, Net::HTTPBadRequest
          JSON.parse(response.body)
        else
          { "errors" => [{ "message" => "#{response.code} #{response.message}" }] }
        end
      end

      # Public: Extension point for subclasses to customize the Net:HTTP client
      #
      # Returns a Net::HTTP object
      def connection
        Net::HTTP.new(uri.host, uri.port).tap do |client|
          client.use_ssl = uri.scheme == "https"
        end
      end

    private

      # generate the form data for a multipart request according to the GraphQL multipart request
      # specification (https://github.com/jaydenseric/graphql-multipart-request-spec/)
      #
      # Example request form data:
      #   operations: {"query": "…", "operationName": "addToGallery", "variables": {"galleryId": "…", images: [null, null, null]}}
      #   map: {"1": ["variables.images.0"], "2": ["variables.images.1"], "3": ["variables.images.2"]}
      #   1: File
      #   2: File
      #   3: File
      #
      # note: modifies `variables`, returns form data (except `operations`) or `nil`
      def form_data!(variables)
        form_data = []
        file_map = {}

        # recursively walk `variables` looking for `File` values, add them to the form data,
        # then replace with `nil`
        stack = variables.map { |k, v|  [variables, ["variables", k], v] }
        while (variable, path, val = stack.pop) do
          if val.is_a?(Hash)
            val.each { |k, v|  stack.push [val, path.dup << k, v] }

          elsif val.is_a?(Array)
            val.each.with_index { |v, i|  stack.push [val, (path.dup << i), v] }

          elsif val.respond_to?(:to_path)
            metadata = { filename: File.basename(val.to_path) }
            metadata[:content_type] = val.content_type  if val.respond_to?(:content_type)

            idx = file_map.length + 1
            file_map[idx.to_s] = [path.map(&:to_s).join(".")]
            form_data.append [idx.to_s, val, metadata]

            variable[path.last] = nil  # replace `IO` value with `nil` in `variables`
          end
        end

        form_data.presence && form_data.append(["map", JSON.generate(file_map)])
      end
    end
  end
end
