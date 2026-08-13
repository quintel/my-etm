# frozen_string_literal: true

require "json_schemer"

# Every v2 endpoint spec applies this matcher so a
# response that drifts from the closed-set contract fails CI instead of drifting unnoticed.
#
#   expect(response.parsed_body).to validate_against_the_v2_envelope
#   expect(response.parsed_body).to validate_against_the_v2_envelope(:collection)
#
# With no argument, the body must match at least one of the response kinds (the Envelope schema's
# anyOf). With a kind given (:resource, :collection, :batch, :accepted, or :error), the body must
# match that kind specifically.
RSpec::Matchers.define(:validate_against_the_v2_envelope) do |kind = nil|
  match do |body|
    schema(kind).valid?(body)
  end

  failure_message do |body|
    errors = schema(kind).validate(body).to_a.map { |e| e["error"] }
    "expected #{body.inspect} to validate against the v2 envelope#{" (#{kind})" if kind}, " \
      "but got:\n#{errors.join("\n")}"
  end

  failure_message_when_negated do |body|
    "expected #{body.inspect} not to validate against the v2 envelope#{" (#{kind})" if kind}, but it did"
  end

  def document
    @document ||= YAML.load_file(Rails.root.join("lib/api/v2/openapi.yaml"))
  end

  def schema(kind)
    JSONSchemer.schema(document, meta_schema: JSONSchemer.openapi31)
                .ref("#/components/schemas/#{(kind || :envelope).to_s.camelize}")
  end
end
