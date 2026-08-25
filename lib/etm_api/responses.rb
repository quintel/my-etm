# frozen_string_literal: true

module EtmApi
  # Builds the body of each response kind named in Envelope::KINDS. These return payloads rather
  # than rendering them, so the shapes are shared while the framework around them is not.
  #
  # Serialising a record is deliberately left to the caller: the serialiser interface is an app
  # concern, and these only wrap whatever it produced.
  module Responses
    # The codes a batch item may carry, keyed by the symbol a service reports.
    #
    # TODO: v1 compares these symbols directly rather than the rendered code, so the services
    # cannot name codes themselves. Revisit when v1 retires.
    ITEM_CODES = {
      not_found: Errors::Codes::NOT_FOUND,
      forbidden: Errors::Codes::FORBIDDEN,
      validation_failed: Errors::Codes::VALIDATION_FAILED,
      internal_error: Errors::Codes::INTERNAL_ERROR
    }.freeze

    module_function

    # The resource and collection kinds share a shape; only the type of `data` differs.
    def data(payload, meta: {})
      { data: payload, meta: meta }
    end

    def ok(extra = {})
      { data: { status: "ok", **extra }, meta: {} }
    end

    def errors(objects)
      { errors: objects }
    end

    # Always reports every submitted item, so a repeated identifier cannot shrink the total.
    def batch(items)
      succeeded = items.count { |item| item[:status] == "ok" }

      {
        data: items,
        meta: { batch: { succeeded: succeeded, failed: items.size - succeeded, total: items.size } }
      }
    end

    def batch_ok(payload)
      { status: "ok", data: payload }
    end

    def batch_error(code:, detail:, pointer:)
      { status: "error", code: code, detail: detail, source: { pointer: pointer } }
    end

    # nil for a code outside the documented set, leaving the caller to decide how to report it.
    def item_code(code)
      ITEM_CODES[code]
    end
  end
end
