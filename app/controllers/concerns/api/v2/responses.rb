module Api
  module V2
    # The render helpers for the Api::V2 response envelope: one per response kind.
    #
    # Every resource-bearing helper takes an explicit `with:` serialiser, so a model can never reach
    # the response through its own as_json.
    module Responses
      extend ActiveSupport::Concern

      # TODO: v1 compares these symbols directly rather than the rendered code, so the services
      # cannot name codes themselves. Revisit when v1 retires.
      ITEM_CODES = {
        not_found: ErrorCodes::NOT_FOUND,
        forbidden: ErrorCodes::FORBIDDEN,
        validation_failed: ErrorCodes::VALIDATION_FAILED,
        internal_error: ErrorCodes::INTERNAL_ERROR
      }.freeze

      included do
        # The request member wrapping this resource. Prefixes every error pointer.
        class_attribute :resource_param_key, instance_writer: false, default: nil
      end

      def render_resource(object, with:, options: {}, meta: {}, status: :ok)
        render json: { data: with.new(object, **options).as_json, meta: meta }, status: status
      end

      def render_collection(objects, with:, meta: {})
        data = objects.map { |object| with.new(object).as_json }

        render json: { data: data, meta: meta }, status: :ok
      end

      # Batch kind, always 207 regardless of whether every item succeeded. One item out per item in,
      # addressed by its position in the request.
      def render_bulk(result, with:, pointer:, options: {})
        items = result.items.map { |item| batch_item(item, with, pointer, options) }
        succeeded = items.count { |item| item[:status] == "ok" }

        render json: {
          data: items,
          meta: { batch: { succeeded: succeeded, failed: items.size - succeeded, total: items.size } }
        }, status: :multi_status
      end

      def render_write(result, with:, options: {}, status: :ok)
        record, errors = normalise_result(result)

        return render_resource(record, with: with, options: options, status: status) if errors.nil?

        render_validation_errors(errors)
      end

      # Every member the action does not accept, one error object each.
      def render_rejected_members(members)
        objects = members.map do |member|
          error_object(
            :bad_request, ErrorCodes::PARAM_INVALID, rejection_detail(member),
            { pointer: json_pointer([ member ]) }
          )
        end

        render json: { errors: objects }, status: :bad_request
      end

      def render_ok(extra = {})
        render json: { data: { status: "ok", **extra }, meta: {} }, status: :ok
      end

      def render_error(status:, code:, detail:, source: nil)
        render json: { errors: [ error_object(status, code, detail, source) ] }, status: status
      end

      # Every failing key, one error object each.
      def render_validation_errors(errors)
        objects = validation_failures(errors.to_hash).map do |path, message|
          error_object(
            :unprocessable_content, ErrorCodes::VALIDATION_FAILED, message, member_source(path)
          )
        end

        # `errors` is required to hold at least one object, a failure can arrive carrying none.
        objects << validation_failed_without_detail if objects.empty?

        render json: { errors: objects }, status: :unprocessable_content
      end

      private

      # Reduces a ServiceResult or a Dry::Monads result to [record, errors], errors nil on success.
      def normalise_result(result)
        return [ result.value!, nil ] if dry_result?(result) && result.success?
        return [ nil, result.failure ] if dry_result?(result)
        return [ result.value, nil ] if result.successful?

        [ nil, result.value&.errors || { base: result.errors } ]
      end

      def dry_result?(result)
        result.is_a?(Dry::Monads::Result)
      end

      # A member the resource does not have at all reads differently from one it will not accept here.
      def rejection_detail(member)
        request_members.include?(member) ? "cannot be set by this action" : "is not a member of this resource"
      end

      # A contract reports a failing collection member as { key => { index => [messages] } }
      def validation_failures(node, path = [])
        case node
        when Hash  then node.flat_map { |key, value| validation_failures(value, path + [ key ]) }
        when Array then node.flat_map { |value| validation_failures(value, path) }
        else [ [ path, node.to_s ] ]
        end
      end

      def member_source(path)
        member, *rest = path
        member = member_aliases.fetch(member.to_s.to_sym) { member.to_s.to_sym }
        return nil unless request_members.include?(member)

        { pointer: json_pointer([ member, *rest ]) }
      end

      def json_pointer(path)
        "/#{[ resource_param_key, *path ].compact.join('/')}"
      end

      def request_members
        []
      end

      # Model attribute names that differ from the request member they describe.
      def member_aliases
        {}
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

      def batch_item(item, serialiser, pointer, options)
        return { status: "ok", **serialiser.new(item.value, **options).as_json } if item.ok?

        {
          status: "error",
          code: item_code(item.code),
          detail: item.messages.join(", "),
          source: { pointer: "#{pointer}/#{item.index}" }
        }
      end

      def item_code(code)
        ITEM_CODES.fetch(code) do
          Sentry.capture_message("Undocumented Api::V2 batch item code: #{code.inspect}")
          ErrorCodes::INTERNAL_ERROR
        end
      end
    end
  end
end
