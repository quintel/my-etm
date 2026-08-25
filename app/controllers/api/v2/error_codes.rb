# frozen_string_literal: true

module Api
  module V2
    # A stable documented enum of machine-readable error code values that is an error contract.
    module ErrorCodes
      UNAUTHENTICATED    = "unauthenticated"     # no usable credential was presented (401)
      PARAM_MISSING      = "param_missing"       # a required parameter was absent (400)
      PARAM_INVALID      = "param_invalid"       # a parameter was present but the wrong shape (400)
      PARSE_ERROR        = "parse_error"         # the request body could not be parsed (400)
      NOT_FOUND          = "not_found"           # the addressed record does not exist (404)
      SCENARIO_NOT_FOUND = "scenario_not_found"  # the addressed SavedScenario does not exist (404)
      FORBIDDEN          = "forbidden"           # the caller may not perform this action (403)
      VALIDATION_FAILED  = "validation_failed"   # the record failed validation (422)
      INTERNAL_ERROR     = "internal_error"      # the item failed unexpectedly (500)
      UPSTREAM_ERROR     = "upstream_error"      # a service this request depends on failed (502)
    end
  end
end
