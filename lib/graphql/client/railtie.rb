# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "rails/railtie"

module GraphQL
  class Client
    # Optional Rails configuration for GraphQL::Client.
    #
    # Simply require this file to activate in the application.
    #
    #   # config/application.rb
    #   require "graphql/client/railtie"
    #
    class Railtie < Rails::Railtie
      config.graphql = ActiveSupport::OrderedOptions.new

      initializer "graphql.configure_log_subscriber" do |_app|
        require "graphql/client/log_subscriber"
        GraphQL::Client::LogSubscriber.attach_to :graphql
      end

      initializer "graphql.configure_erb_implementation" do |_app|
        require "graphql/client/erb"
        ActionView::Template::Handlers::ERB.erb_implementation = GraphQL::Client::ERB
      end

      config.after_initialize do |app|
        require "graphql/client/view_module"

        path = config.graphql.client_views_path || app.paths["app/views"].first

        # TODO: Accessing config.graphql.client during the initialization
        # process seems error prone. The application may reassign
        # config.graphql.client after this block is executed.
        client = config.graphql.client

        config.watchable_dirs[path] = [:erb]

        Object.const_set(:Views, Module.new do
          extend GraphQL::Client::ViewModule
          self.path = path
          self.client = client
        end)
      end
    end
  end
end
