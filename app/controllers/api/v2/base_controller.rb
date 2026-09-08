# frozen_string_literal: true

module Api
  module V2
    class BaseController < ActionController::API
      include ActionController::MimeResponds
      include Api::V2::Responses

      # The most items one v2 request may carry, whether as a batch or as a member list.
      BATCH_LIMIT = 100

      check_authorization

      # Authenticated by default: an endpoint open to anonymous callers skips this deliberately.
      before_action :require_user

      after_action :track_token_use

      rescue_from ActionController::ParameterMissing do |e|
        render_error(
          status: :bad_request,
          code: ErrorCodes::PARAM_MISSING,
          detail: "param is missing or the value is empty: #{e.param}",
          source: param_source(e.param)
        )
      end

      rescue_from InvalidParam do |e|
        render_invalid_param(pointer: e.pointer, detail: e.message)
      end

      rescue_from UnacceptedMembers do |e|
        render_rejected_members(e.members)
      end

      rescue_from OversizedMember do |e|
        render_validation_errors(e.member => [ "size cannot be greater than #{BATCH_LIMIT}" ])
      end

      rescue_from ActiveRecord::RecordNotFound do |e|
        render_not_found(code: not_found_code(e.model), detail: not_found_detail(e.model))
      end

      rescue_from ActiveModel::RangeError do
        render_not_found(code: ErrorCodes::NOT_FOUND, detail: "Not found")
      end

      rescue_from CanCan::AccessDenied do |e|
        render_denied(e.subject)
      end

      def process_action(*args)
        super
      rescue ActionDispatch::Http::Parameters::ParseError => e
        render_error(status: :bad_request, code: ErrorCodes::PARSE_ERROR, detail: e.message)
      end

      private

      # Reads the resource member, refusing a member the action does not accept
      def resource_params(*scalars, **lists)
        submitted = params.require(resource_param_key)

        reject_unaccepted_members(submitted, scalars + lists.keys)
        scalars.each   { |member| require_scalar(submitted, member) }
        lists.each_key { |member| require_list(submitted, member) }
        lists.each_key { |member| require_within_limit(submitted, member) }

        submitted.permit(*scalars, **lists)
      end

      # Read-only members are ignored, not refused, so a caller can send back what it fetched.
      def reject_unaccepted_members(submitted, accepted)
        unaccepted = submitted.keys.map(&:to_sym) - accepted - readonly_members
        raise UnacceptedMembers, unaccepted if unaccepted.any?
      end

      def require_list(submitted, member)
        value = submitted[member]
        return if value.nil? || value.is_a?(Array)

        raise InvalidParam.new(json_pointer([ member ]), "#{member} must be an array")
      end

      # Without this, permit silently discards an array or object sent for a scalar member.
      def require_scalar(submitted, member)
        value = submitted[member]
        return unless value.is_a?(Array) || value.is_a?(ActionController::Parameters)

        raise InvalidParam.new(json_pointer([ member ]), "#{member} must be a single value")
      end

      # Every declared list is capped, so BATCH_LIMIT holds without an action opting in.
      def require_within_limit(submitted, member)
        return if Array(submitted[member]).size <= BATCH_LIMIT

        raise OversizedMember, member
      end

      # Renders and returns true when a version tag cannot be resolved.
      def reject_unknown_version(tag)
        return false if tag.blank? || Version.exists?(tag: tag)

        render_validation_errors(version: [ "is not a known version" ])
        true
      end

      def param_source(param)
        return { pointer: "/#{param}" } if param.to_s == resource_param_key.to_s

        member_source([ param ])
      end

      def render_invalid_param(pointer:, detail:)
        render_error(
          status: :bad_request,
          code: ErrorCodes::PARAM_INVALID,
          detail: detail,
          source: { pointer: pointer }
        )
      end

      # With a caller: hidden or refused, depending on access.
      def render_denied(subject)
        return render_unauthenticated unless current_user

        if subject.is_a?(Class) || current_ability.can?(:read, subject)
          render_error(status: :forbidden, code: ErrorCodes::FORBIDDEN, detail: denied_detail(subject))
        else
          render_error(status: :not_found, code: ErrorCodes::NOT_FOUND, detail: "Not found")
        end
      end

      # An anonymous caller is told to authenticate rather than whether the record exists.
      def render_not_found(code:, detail:)
        return render_unauthenticated unless current_user

        render_error(status: :not_found, code: code, detail: detail)
      end

      def denied_detail(subject)
        model = subject.is_a?(Class) ? subject : subject.class
        "Not permitted to #{action_name} this #{model.name.underscore.humanize.downcase}"
      end

      def not_found_code(model)
        model == "SavedScenario" ? ErrorCodes::SCENARIO_NOT_FOUND : ErrorCodes::NOT_FOUND
      end

      def not_found_detail(model)
        model ? "#{model.underscore.humanize} not found" : "Not found"
      end

      # A v2 request authenticates from an `Authorization: Bearer` credential only
      def current_token
        return @current_token if defined?(@current_token)

        credential = request.authorization.to_s[/\ABearer (.+)\z/, 1]
        token = credential.present? ? Doorkeeper::AccessToken.by_token(credential) : nil

        @current_token = token if token&.accessible?
      end

      def current_user
        return @current_user if defined?(@current_user)

        @current_user = User.find_by(id: current_token&.resource_owner_id)
      end

      def current_ability
        @current_ability ||=
          if current_user
            Api::TokenAbility.new({ scopes: current_token.scopes.to_a }, current_user)
          else
            Api::GuestAbility.new
          end
      end

      # The ability's id lists are built once per request, so a resource created during it is absent.
      def reset_ability!
        @current_ability = nil
      end

      def require_user
        return if current_user

        render_unauthenticated
      end

      # The single 401 route.
      def render_unauthenticated
        response.set_header("WWW-Authenticate", 'Bearer realm="api"')

        render_error(status: :unauthorized, code: ErrorCodes::UNAUTHENTICATED, detail: "Not authenticated")
      end

      # PAT usage reporting
      def track_token_use
        return unless response.successful? && current_token
        return unless PersonalAccessToken.prefixed?(current_token.token)

        TrackPersonalAccessTokenUse.perform_later(current_token.id, Time.now.utc)
      end
    end
  end
end
