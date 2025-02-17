module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::MimeResponds

      after_action :track_token_use

      rescue_from ActionController::ParameterMissing do |e|
        render status: 400, json: { errors: ["param is missing or the value is empty: #{e.param}"] }
      end

      rescue_from ActiveRecord::RecordNotFound do |e|
        if e.model
          render_not_found(errors: ["#{e.model.underscore.humanize} not found"])
        else
          render_not_found
        end
      end

      rescue_from ActiveModel::RangeError do
        render_not_found
      end

      rescue_from CanCan::AccessDenied do |e|
        if e.subject.is_a?(SavedScenario) && !e.subject.private?
          render status: :forbidden, json: { errors: [ "Scenario does not belong to you" ] }
        elsif e.subject.is_a?(Collection)
          render status: :forbidden, json: { errors: [ "Collection does not belong to you" ] }
        else
          render_not_found
        end
      end

      rescue_from MyEtm::Auth::DecodeError do
        render json: { errors: [ "Invalid or expired token" ] }, status: :unauthorized
      end

      private

      def decoded_token
        return @decoded_token if defined?(@decoded_token)

        auth_header = request.headers["Authorization"]
        token = auth_header&.split(" ")&.last
        return nil unless token

        @decoded_token = MyEtm::Auth.decode(token)
      rescue MyEtm::Auth::DecodeError, MyEtm::Auth::TokenExchangeError => e
        Rails.logger.debug("Token decoding failed: #{e.message}")
        nil
      end

      # Fetch the user based on the decoded token or session.
      def current_user
        return @current_user if defined?(@current_user)

        if decoded_token
          @current_user = User.find(decoded_token[:sub])
        elsif doorkeeper_token
          @current_user = User.find(doorkeeper_token.resource_owner_id)
        end
      end

      def current_ability
        @current_ability ||= begin
          if current_user
            if decoded_token
              TokenAbility.new(decoded_token, current_user)
            elsif doorkeeper_token
              TokenAbility.new(doorkeeper_token, current_user)
            else
              GuestAbility.new
            end
          else
            GuestAbility.new
          end
        end
      end

      # Send a 404 response with an optional JSON body.
      def render_not_found(body = { errors: [ "Not found" ] })
        render json: body, status: :not_found
      end

      # Processes the controller action.
      #
      # Wraps around the default to rescue malformed params (e.g. JSON bodies)
      # which is currently not possible with `rescue_from`.
      #
      # See: https://github.com/rails/rails/issues/38285
      def process_action(*args)
        super
      rescue ActionDispatch::Http::Parameters::ParseError => e
        render status: 400, json: { errors: [ e.message ] }
      end

      def track_token_use
        if response.status == 200 && doorkeeper_token && doorkeeper_token.application_id.nil?
          TrackPersonalAccessTokenUse.perform_later(doorkeeper_token.id, Time.now.utc)
        end
      end

      def require_user
        render_not_found(errors: ['User not identified']) unless current_user
      end
    end
  end
end
