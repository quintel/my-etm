# frozen_string_literal: true

module Api
  module V2
    # A stable documented enum of machine-readable error code values that is an error contract.
    # TODO: @noracato can you check that you agree with the codes and their meanings? Because this
    # should be the definitive list and I think we should document it in the API docs and stay consistent
    # to a certain subset.
    module ErrorCodes
      UNAUTHENTICATED    = "unauthenticated"     # no usable credential was presented (401)
      PARAM_MISSING      = "param_missing"       # a required parameter was absent (400)
      PARSE_ERROR        = "parse_error"         # the request body could not be parsed (400)
      NOT_FOUND          = "not_found"           # a referenced record does not exist (404)
      SCENARIO_NOT_FOUND = "scenario_not_found"  # a referenced SavedScenario does not exist (404)
      FORBIDDEN          = "forbidden"           # the caller may not perform this action (403)
      VALIDATION_FAILED  = "validation_failed"   # the record failed validation (422)
    end
  end
end
