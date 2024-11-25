module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::MimeResponds

      before_action :authenticate_request!

      rescue_from ActionController::ParameterMissing do |e|
        render json: { errors: [e.message] }, status: :bad_request
      end

      rescue_from ActiveRecord::RecordNotFound do |e|
        render json: {
          errors: ["No such #{e.model.underscore.humanize.downcase}: #{e.id}"]
        }, status: :not_found
      end

      rescue_from ActiveModel::RangeError do
        render_not_found
      end

      rescue_from CanCan::AccessDenied do |e|
        if e.subject.is_a?(SavedScenario) && !e.subject.private?
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

      # Fetch the user based on the decoded token or session.
      def current_user
        return @current_user if defined?(@current_user)

        if decoded_token
          @current_user = find_user_from_token
        elsif doorkeeper_token
          @current_user = find_user_from_session
        end
      end

      def current_ability
        @current_ability ||= begin
          if current_user
            if decoded_token
              TokenAbility.new(decoded_token, current_user)
            elsif doorkeeper_token
              TokenAbility.new(doorkeeper_token, current_user)
            end
          else
            GuestAbility.new
          end
        end
      end

      def authenticate_request!
        if doorkeeper_token
          doorkeeper_authorize!
          @current_user = User.find(doorkeeper_token.resource_owner_id)
        elsif decoded_token
          unless current_user
            render json: { errors: ['Unauthorized'] }, status: :unauthorized
          end
        else
          render json: { errors: ['Authentication required'] }, status: :unauthorized
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

      private

      def find_user_from_token
        return unless decoded_token
        user_data = decoded_token[:user]
        User.find_or_create_by(id: decoded_token[:sub]) do |user|
          user.assign_attributes(user_data)

        end
      end

      def find_user_from_session
        user = User.find_or_create_by(id: doorkeeper_token.resource_owner_id) if doorkeeper_token
        user
      rescue ActiveRecord::RecordNotFound
        reset_session
        redirect_to root_path
        nil
      end
    end
  end
end
