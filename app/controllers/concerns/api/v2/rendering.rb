module Api
  module V2
    # Renders each Api::V2 response kind. The payloads themselves are built by EtmApi::Responses.
    #
    # Every resource-bearing helper takes an explicit `with:` serialiser, so a model can never reach
    # the response through its own as_json.
    module Rendering
      extend ActiveSupport::Concern

      included do
        # The request member wrapping this resource. Prefixes every error pointer.
        class_attribute :resource_param_key, instance_writer: false, default: nil
      end

      def render_resource(object, with:, options: {}, meta: {}, status: :ok)
        payload = EtmApi::Responses.data(with.new(object, **options).as_json, meta: meta)

        render json: payload, status: status
      end

      def render_collection(objects, with:, options: {}, meta: {})
        serialised = objects.map { |object| with.new(object, **options).as_json }

        render json: EtmApi::Responses.data(serialised, meta: meta), status: :ok
      end

      # Batch kind, always 207 regardless of whether every item succeeded. One item out per item in,
      # addressed by its position in the request.
      def render_batch(result, with:, pointer:, options: {})
        items = result.items.map { |item| batch_item(item, with, pointer, options) }

        render json: EtmApi::Responses.batch(items), status: :multi_status
      end

      def render_write(result, with:, options: {}, status: :ok)
        if result.success?
          return render_resource(result.value!, with: with, options: options, status: status)
        end

        failure = result.failure
        return render_upstream_error(failure.last) if upstream_failure?(failure)

        render_validation_errors(failure)
      end

      # Every member the action does not accept, one error object each.
      def render_rejected_members(members, path: [])
        objects = members.map do |member|
          EtmApi::Responses::ErrorObject.build(
            status: :bad_request,
            code: EtmApi::Errors::Codes::PARAM_INVALID,
            detail: rejection_detail(member),
            source: { pointer: json_pointer([ *path, member ]) }
          )
        end

        render json: EtmApi::Responses.errors(objects), status: :bad_request
      end

      def render_ok(extra = {})
        render json: EtmApi::Responses.ok(extra), status: :ok
      end

      # The one route to a 204, so it stays inside the closed set of kinds.
      def render_no_content
        head :no_content
      end

      def render_error(status:, code:, detail:, source: nil)
        object = EtmApi::Responses::ErrorObject.build(
          status: status, code: code, detail: detail, source: source
        )

        render json: EtmApi::Responses.errors([ object ]), status: status
      end

      # Every failing key, one error object each.
      def render_validation_errors(errors)
        objects = EtmApi::Responses::Validation.failures(errors.to_hash).map do |path, message|
          EtmApi::Responses::ErrorObject.build(
            status: :unprocessable_content,
            code: EtmApi::Errors::Codes::VALIDATION_FAILED,
            detail: message,
            source: member_source(path)
          )
        end

        objects << EtmApi::Responses::Validation.unspecified_failure if objects.empty?

        render json: EtmApi::Responses.errors(objects), status: :unprocessable_content
      end

      private

      # A failure naming no request member is not the caller's to fix, so it must not read as a
      # validation failure. A service says so by tagging it.
      def upstream_failure?(failure)
        failure.is_a?(Array) && failure.first == :upstream
      end

      def render_upstream_error(messages)
        render_error(
          status: :bad_gateway,
          code: EtmApi::Errors::Codes::UPSTREAM_ERROR,
          detail: Array(messages).join(", ").presence || "The request could not be completed"
        )
      end

      # Read-only members are ignored before rejection, so only these two cases reach here.
      def rejection_detail(member)
        return "cannot be set by this action" if request_members.include?(member)

        "is not a member of this resource"
      end

      # Rails names an error on an indexed association `members[1].attribute`. The member and the
      # position are what a pointer needs; `base` names the record as a whole, so it adds nothing.
      INDEXED_MEMBER = /\A(?<member>\w+)\[(?<index>\d+)\]\.(?<attribute>\w+)\z/

      def member_source(path)
        member, *rest = at_index(path)
        member = member_aliases.fetch(member.to_s.to_sym) { member.to_s.to_sym }
        return nil unless request_members.include?(member)

        { pointer: json_pointer([ member, *rest ]) }
      end

      def at_index(path)
        first, *rest = path
        match = INDEXED_MEMBER.match(first.to_s)
        return path unless match

        attribute = match[:attribute] == "base" ? [] : [ match[:attribute].to_sym ]

        [ match[:member], match[:index].to_i, *attribute, *rest ]
      end

      def json_pointer(path)
        "/#{[ resource_param_key, *path ].compact.join('/')}"
      end

      def request_members
        raise NotImplementedError, "#{self.class.name} must declare request_members"
      end

      # Members the resource shows but doesn't accept
      def readonly_members
        %i[id created_at updated_at]
      end

      # Model attribute names that differ from the request member they describe.
      def member_aliases
        {}
      end

      def batch_item(item, serialiser, pointer, options)
        return EtmApi::Responses.batch_ok(serialiser.new(item.value, **options).as_json) if item.ok?

        EtmApi::Responses.batch_error(
          code: item_code(item.code),
          detail: item.messages.join(", "),
          pointer: "#{pointer}/#{item.index}"
        )
      end

      # Reporting an undocumented code is this app's policy, so it stays out of the shared map.
      def item_code(code)
        EtmApi::Responses.item_code(code) || begin
          Sentry.capture_message("Undocumented Api::V2 batch item code: #{code.inspect}")
          EtmApi::Errors::Codes::INTERNAL_ERROR
        end
      end
    end
  end
end
