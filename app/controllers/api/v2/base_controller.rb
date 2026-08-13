# frozen_string_literal: true

module Api
  module V2
    class BaseController < ActionController::API
      include ActionController::MimeResponds
      include Api::V2::Serialisable

      check_authorization

      after_action :track_token_use

      rescue_from ActionController::ParameterMissing do |e|
        render_error(
          status: :bad_request,
          code: ErrorCodes::PARAM_MISSING,
          detail: "param is missing or the value is empty: #{e.param}",
          source: { parameter: e.param.to_s }
        )
      end

      rescue_from ActiveRecord::RecordNotFound do |e|
        render_error(status: :not_found, code: not_found_code(e.model), detail: not_found_detail(e.model))
      end

      rescue_from ActiveModel::RangeError do
        render_error(status: :not_found, code: ErrorCodes::NOT_FOUND, detail: "Not found")
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

      # Hidden or refused, depending on access.
      def render_denied(subject)
        if subject.is_a?(Class) || current_ability.can?(:read, subject)
          render_error(status: :forbidden, code: ErrorCodes::FORBIDDEN, detail: denied_detail(subject))
        else
          render_error(status: :not_found, code: ErrorCodes::NOT_FOUND, detail: "Not found")
        end
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

      def require_user
        return if current_user

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
