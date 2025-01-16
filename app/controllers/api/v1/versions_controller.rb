module Api
  module V1
    class VersionsController < BaseController
      skip_before_action :authenticate_request!

      def index
        versions = Version.all
        versions = versions.where(tag: params[:tag]) if params[:tag].present?
        versions = versions.order(created_at: :desc) if params[:sort] == 'desc'

        render json: { versions: versions.as_json }, status: :ok
      end
    end
  end
end
