# frozen_string_literal: true
require "graphql"
if GraphQL::VERSION > "1.8"
  GraphQL::DeprecatedDSL.activate
end

require "ostruct"
require "time"
require "json"
require "erubi"
require "erubis"
require "graphql/client"
require "graphql/client/http"
require "graphql/client/collocated_enforcement"
require "graphql/language/nodes/deep_freeze_ext"
require "graphql/client/definition_variables"
require "graphql/client/erubi_enhancer"
require "graphql/client/erubis_enhancer"
require "graphql/client/erubis"
require "graphql/client/view_module"
require "graphql/client/hash_with_indifferent_access"
require "graphql/client/schema"
require "rubocop/cop/graphql/heredoc"
require "rubocop/cop/graphql/overfetch"

require "foo_helper"
require "minitest/autorun"
