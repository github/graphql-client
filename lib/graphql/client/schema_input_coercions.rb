# frozen_string_literal: true
require "set"

module GraphQL
  class Client
    FALSE_VALUES = [false, 0, "0", "f", "F", "false", "FALSE", "off", "OFF"].to_set.freeze

    SchemaInputCoercions = {}

    SchemaInputCoercions["Boolean"] = ->(value, ctx) {
      if value == ""
        nil
      elsif FALSE_VALUES.include?(value)
        false
      else
        !!value
      end
    }

    SchemaInputCoercions["Int"] = ->(value, ctx) {
      case value
      when true then 1
      when false then 0
      else value.to_i
      end
    }

    SchemaInputCoercions["Float"] = ->(value, ctx) {
      value.to_f
    }

    SchemaInputCoercions["String"] = ->(value, ctx) {
      case value
      when true then "t"
      when false then "f"
      else value.to_s
      end
    }
  end
end
