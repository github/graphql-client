# frozen_string_literal: true

# Monkeypatch to allow magic GraphQL casting
ActionView::Template::Handlers::ERB.class_eval do
  def call(template)
    if template.source.encoding_aware?
      # First, convert to BINARY, so in case the encoding is
      # wrong, we can still find an encoding tag
      # (<%# encoding %>) inside the String using a regular
      # expression
      template_source = template.source.dup.force_encoding("BINARY")

      erb = template_source.gsub(ActionView::Template::Handlers::ERB::ENCODING_TAG, "")
      encoding = $2

      erb.force_encoding valid_encoding(template.source.dup, encoding)

      # Always make sure we return a String in the default_internal
      erb.encode!
    else
      erb = template.source.dup
    end

    self.class.erb_implementation.new(
      erb,
      filename: template.inspect, # We need this passed as a property to figure out magic modules
      escape: (self.class.escape_whitelist.include? template.mime_type),
      trim: (self.class.erb_trim_mode == "-")
    ).src
  end
end
