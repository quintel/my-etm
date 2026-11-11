# frozen_string_literal: true

module Api
  module V1
    class AnnouncementsController < BaseController
      # GET /api/v1/announcements
      #
      # The active announcement of the version given by the `version` param (a tag such as
      # "2027"), or of the default version when there is no param.
      def index
        version = params[:version].present? ? Version.find_by(tag: params[:version]) : Version.default

        render json: { announcements: Announcement.active.where(version:).as_json }, status: :ok
      end
    end
  end
end
