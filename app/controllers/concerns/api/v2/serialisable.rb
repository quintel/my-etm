module Api
  module V2
    # Serialiser logic shared for API responses.
    module Serialisable
      def render_resource(data, meta: {}, status: :ok)
        render json: { data: data, meta: meta }, status: status
      end

      def render_collection(data, meta:)
        render json: { data: data, meta: meta }, status: :ok
      end

      # Batch kind, always 207 regardless of whether every item succeeded, so a batch endpoint's
      # contract never changes shape between an all-success and a partial-success run.
      def render_batch(items)
        succeeded = items.count { |item| item[:status] == "ok" }

        render json: {
          data: items,
          meta: { batch: { succeeded: succeeded, failed: items.size - succeeded, total: items.size } }
        }, status: :multi_status
      end

      def render_accepted(extra = {})
        render json: { data: { status: "accepted", **extra }, meta: {} }, status: :ok
      end

      def render_error(status:, code:, detail:, source: nil)
        render json: { errors: [ error_object(status, code, detail, source) ] }, status: status
      end

      # Every failing key at once, one error object each
      def render_validation_errors(errors)
        objects = errors.to_h.flat_map do |attribute, messages|
          Array(messages).map do |message|
            error_object(:unprocessable_content, ErrorCodes::VALIDATION_FAILED, message.to_s, { pointer: attribute.to_s })
          end
        end

        render json: { errors: objects }, status: :unprocessable_content
      end

      def error_object(status, code, detail, source)
        object = { status: Rack::Utils.status_code(status), code: code.to_s, detail: detail }
        object[:source] = source if source
        object
      end

      # batch update
      # returns { data: [{status}], meta: {}, batch: {succeeded,failed,total} }
      def serialise_batch_update(results_or_resources);end
    end
  end
end
