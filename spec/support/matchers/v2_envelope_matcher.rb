# frozen_string_literal: true

# Every v2 endpoint spec applies this matcher so a response that drifts from the closed set of kinds
# fails CI instead of drifting unnoticed. The kinds themselves live in ApiV2Envelope.
#
#   expect(response.parsed_body).to validate_against_the_v2_envelope
#   expect(response.parsed_body).to validate_against_the_v2_envelope(:collection)
#
# With a kind given, the body must be that kind. With no argument, it must be one of them. What goes
# *inside* `data` is each serialiser's own allow-list, pinned by spec/serialisers/api/v2.
RSpec::Matchers.define(:validate_against_the_v2_envelope) do |kind = nil|
  match do |body|
    next ApiV2Envelope.violations(body, kind).empty? if kind

    ApiV2Envelope::KINDS.any? { |candidate| ApiV2Envelope.violations(body, candidate).empty? }
  end

  failure_message do |body|
    unless kind
      next "expected #{body.inspect} to be one of the v2 response kinds " \
           "(#{ApiV2Envelope::KINDS.join(', ')}), but it matched none"
    end

    violations = ApiV2Envelope.violations(body, kind)
    "expected #{body.inspect} to be the v2 #{kind} kind, but:\n- #{violations.join("\n- ")}"
  end

  failure_message_when_negated do |body|
    "expected #{body.inspect} not to be#{kind ? " the v2 #{kind} kind" : ' a v2 response kind'}, " \
      "but it was"
  end
end
