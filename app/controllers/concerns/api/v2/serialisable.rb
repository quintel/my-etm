module Api
  module V2
    # Serialiser logic shared for API responses.
    #
    # Every resource-bearing helper takes an explicit `with:` serialiser, so a model must always go
    # through serialisable, not as_json
    module Serialisable
      def render_resource(object, with:, meta: {}, status: :ok)
        render json: { data: with.new(object).as_json, meta: meta }, status: status
      end

      def render_collection(objects, with:, meta: {})
        data = objects.map { |object| with.new(object).as_json }

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

      # Renders a BulkResult as the batch kind. One item out per item in, addressed by its position
      def render_bulk(result, with:, pointer:)
        render_batch(result.items.map { |item| batch_item(item, with, pointer) })
      end

      def render_accepted(extra = {})
        render json: { data: { status: "accepted", **extra }, meta: {} }, status: :ok
      end

      def render_error(status:, code:, detail:, source: nil)
        render json: { errors: [ error_object(status, code, detail, source) ] }, status: status
      end

      # Every failing key at once, one error object each.
      def render_validation_errors(errors)
        objects = errors.to_hash.flat_map do |attribute, messages|
          Array(messages).map do |message|
            error_object(:unprocessable_content, ErrorCodes::VALIDATION_FAILED, message.to_s, { pointer: attribute.to_s })
          end
        end

        render json: { errors: objects }, status: :unprocessable_content
      end

      private

      def error_object(status, code, detail, source)
        object = { status: Rack::Utils.status_code(status), code: code.to_s, detail: detail }
        object[:source] = source if source
        object
      end

      def batch_item(item, serialiser, pointer)
        return { status: "ok", **serialiser.new(item.value).as_json } if item.ok?

        {
          status: "error",
          code: item.code.to_s,
          detail: item.messages.join(", "),
          source: { pointer: "#{pointer}/#{item.index}" }
        }
      end
    end
  end
end
