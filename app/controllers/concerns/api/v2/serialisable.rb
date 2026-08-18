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
      # contract never changes shape between an all-success and a partial-success run. One item out
      # per item in, addressed by its position in the request.
      def render_bulk(result, with:, pointer:)
        items = result.items.map { |item| batch_item(item, with, pointer) }
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

      # Every failing key at once, one error object each.
      def render_validation_errors(errors)
        objects = validation_failures(errors.to_hash).map do |pointer, message|
          error_object(:unprocessable_content, ErrorCodes::VALIDATION_FAILED, message, { pointer: pointer })
        end

        # `errors` is required to hold at least one object, and a failure can arrive carrying none.
        objects << validation_failed_without_detail if objects.empty?

        render json: { errors: objects }, status: :unprocessable_content
      end

      private

      # A contract reports a failing collection member as { key => { index => [messages] } }
      def validation_failures(node, path = [])
        case node
        when Hash  then node.flat_map { |key, value| validation_failures(value, path + [ key ]) }
        when Array then node.flat_map { |value| validation_failures(value, path) }
        else [ [ path.join("/"), node.to_s ] ]
        end
      end

      def validation_failed_without_detail
        error_object(
          :unprocessable_content, ErrorCodes::VALIDATION_FAILED, "The request could not be applied", nil
        )
      end

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
