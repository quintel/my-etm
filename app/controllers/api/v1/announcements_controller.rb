# frozen_string_literal: true

module Api
  module V1
    class AnnouncementsController < BaseController
      # GET /api/v1/announcements
      def index
        render json: { announcements: Announcement.active.as_json }, status: :ok
      end
    end
  end
end
