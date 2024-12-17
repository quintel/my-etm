module Api
  module V1
    class VersionsController < BaseController
      skip_before_action :authenticate_request!

      def index
        render json: { versions: Version.as_json }, status: :ok
      end
    end
  end
end
