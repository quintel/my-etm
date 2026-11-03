# frozen_string_literal: true

module Admin
  # Edits the announcement shown in the ETM front-ends of each version.
  class AnnouncementsController < ApplicationController
    include AdminController

    before_action :set_version, :set_announcement

    def edit; end

    def update
      if @announcement.update(announcement_params)
        flash[:notice] = t("admin.announcements.success")
        redirect_to edit_admin_announcement_path(version: @version.tag)
      else
        render(:edit, status: :unprocessable_entity)
      end
    end

    private

    # Without a version param, the default version's announcement. An unknown tag is not found.
    def set_version
      @version = params[:version].present? ? Version.find_by!(tag: params[:version]) : Version.default
    end

    def set_announcement
      @announcement = Announcement.editable(@version)
      @shown_version_ids = Announcement.active.pluck(:version_id)
    end

    def announcement_params
      params.require(:announcement).permit(:active, :body_en, :body_nl)
    end
  end
end
