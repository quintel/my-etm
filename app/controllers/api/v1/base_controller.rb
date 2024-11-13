module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::MimeResponds

      before_action :authenticate_request!

      rescue_from CanCan::AccessDenied do |e|
        if e.subject.is_a?(Scenario) && !e.subject.private?
          render status: :forbidden, json: { errors: ['Scenario does not belong to you'] }
        else
          render_not_found
        end
      end

      rescue_from MyEtm::Auth::DecodeError do
        render json: { errors: ['Invalid or expired token'] }, status: :unauthorized
      end

      private


      def decoded_token
        return @decoded_token if defined?(@decoded_token)

        auth_header = request.headers['Authorization']
        token = auth_header&.split(' ')&.last
        return nil unless token

        @decoded_token = MyEtm::Auth.decode(token)
      rescue MyEtm::Auth::DecodeError, MyEtm::Auth::TokenExchangeError => e
        Rails.logger.debug "Token decoding failed: #{e.message}"
        nil
      end

      # Fetch the user based on the decoded token's subject
      def current_user
        return @current_user if defined?(@current_user)

        if decoded_token
          user_id = decoded_token[:sub]
          @current_user = User.find_by(id: user_id) # Use `find_by` to avoid exceptions for missing records
        end
        @current_user
      end

      def current_ability
        @current_ability ||=
          if current_user
            TokenAbility.new(decoded_token, current_user)
          else
            GuestAbility.new
          end
      end

      def authenticate_request!

        if decoded_token
          render json: { errors: ['Unauthorized'] }, status: :unauthorized unless current_user
        end
      end

      # Many API actions require an active scenario. Let's set it here
      # and let's prepare the field for the calculations.
      #
      def set_current_scenario
        @scenario = if params[:scenario_id]
          Scenario.find(params[:scenario_id])
        else
          Scenario.last
        end
      end

      # Send a 404 response with an optional JSON body.
      def render_not_found(body = { errors: ['Not found'] })
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
        render status: 400, json: { errors: [e.message] }
      end

      def track_token_use
        if response.status == 200 && decoded_token && decoded_token.application_id.nil?
          TrackPersonalAccessTokenUse.perform_later(decoded_token.id, Time.now.utc)
        end
      end

      def require_user
        return if current_user

        redirect_to new_user_session_path
        false
      end
    end
  end
end
