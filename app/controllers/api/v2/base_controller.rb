module Api
  module V2
    class BaseController < ActionController::API
      include ActionController::MimeResponds

      after_action :track_token_use

      # TODO: add rescues


      private

      def render_not_found;end

      def render_bad_params;end

      def render_accepted;end

      # TODO: could be here or in/from status in Serialisable.
      def render_ok(response)
        render json: response, status: :ok
      end

      def render_error(status:, code:, detail:, source:);end



      # TODO @Louis: hook auth logic to find current user and track token use
      # Track PAT use
      def track_token_use;end

      def current_user;end

      def require_user;end
    end
  end
end
