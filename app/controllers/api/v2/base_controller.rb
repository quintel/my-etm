module Api
  module V2
    class BaseController < ActionController::API
      include ActionController::MimeResponds

      after_action :track_token_use

      # TODO: add rescues
      #
      # TODO@Louis: I just copied this from the v1 base - should get an update
      # to fix the 404 & 403's
      rescue_from CanCan::AccessDenied do |e|
        if e.subject.is_a?(SavedScenario) && !e.subject.private?
          render status: :forbidden, json: { errors: [ "Scenario does not belong to you" ] }
        elsif e.subject.is_a?(Collection)
          render status: :forbidden, json: { errors: [ "Collection does not belong to you" ] }
        else
          render_not_found
        end
      end


      private

      def render_not_found(body = { errors: [ "Not found" ] })
        render json: body, status: :not_found
      end

      def render_bad_params;end

      def render_accepted;end


      def render_ok(response)
        render json: response, status: :ok
      end

      def render_created(response)
        render json: response, status: :created
      end

      def render_error(response, status: :unprocessable_entity)
        render json: response, status:
      end


      # TODO @Louis: hook auth logic to find current user and track token use
      # Track PAT use
      def track_token_use;end

      def current_user;end

      def require_user;end
    end
  end
end
