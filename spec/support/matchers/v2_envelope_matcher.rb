# frozen_string_literal: true

require "json_schemer"

# Every v2 endpoint spec applies this matcher so a
# response that drifts from the closed-set contract fails CI instead of drifting unnoticed.
#
#   expect(response.parsed_body).to validate_against_the_v2_envelope
#   expect(response.parsed_body).to validate_against_the_v2_envelope(:collection)
#
# With a kind given, the body must match that kind. With no argument, it must match at least one of
# them. A kind may also name a per-resource narrowing, such as :saved_scenario_user_batch.
RSpec::Matchers.define(:validate_against_the_v2_envelope) do |kind = nil|
  match do |body|
    if kind
      schema(kind).valid?(body)
    else
      response_kinds.any? { |candidate| schema(candidate).valid?(body) }
    end
  end

  failure_message do |body|
    return "expected #{body.inspect} to match one of the v2 response kinds " \
      "(#{response_kinds.join(', ')}), but it matched none" unless kind

    errors = schema(kind).validate(body).to_a.map { |error| error["error"] }
    "expected #{body.inspect} to validate against the v2 envelope (#{kind}), " \
      "but got:\n#{errors.join("\n")}"
  end

  failure_message_when_negated do |body|
    "expected #{body.inspect} not to validate against the v2 envelope#{" (#{kind})" if kind}, but it did"
  end

  # The closed set of response kinds.
  def response_kinds
    %i[resource collection batch ok error]
  end

  def document
    @document ||= YAML.load_file(Rails.root.join("lib/api/v2/openapi.yaml"))
  end

  def schema(kind)
    JSONSchemer.schema(document, meta_schema: JSONSchemer.openapi31)
                .ref("#/components/schemas/#{kind.to_s.camelize}")
  end
end
