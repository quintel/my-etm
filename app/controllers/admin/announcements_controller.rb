# frozen_string_literal: true

module Admin
  # Edits the announcement shown in the ETM front-ends.
  class AnnouncementsController < ApplicationController
    include AdminController

    before_action :set_announcement

    def edit; end

    def update
      if @announcement.update(announcement_params)
        flash[:notice] = t("admin.announcements.success")
        redirect_to edit_admin_announcement_path
      else
        render(:edit, status: :unprocessable_entity)
      end
    end

    private

    def set_announcement
      @announcement = Announcement.editable
    end

    def announcement_params
      params.require(:announcement).permit(:active, :body_en, :body_nl)
    end
  end
end
