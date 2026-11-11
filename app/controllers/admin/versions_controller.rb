# frozen_string_literal: true

module Admin
  class VersionsController < ApplicationController
    include AdminController

    load_resource only: %i[update destroy confirm_destroy]
    before_action :check_deletable, only: %i[destroy confirm_destroy]

    # GET /admin/versions
    def index
      @versions = Version.all
    end

    # GET /admin/versions/new
    def new
      @version = Version.new(hidden: true)
    end

    # POST /admin/versions
    #
    # Shows the new applications' client IDs and secrets on the response itself, so they are
    # displayed once.
    def create
      result = CreateVersion.call(
        tag: version_params[:tag],
        released_on: version_params[:released_on],
        hidden: ActiveModel::Type::Boolean.new.cast(version_params[:hidden])
      )

      if result.success?
        @version = result.value!
        render(:created, status: :created)
      else
        @version = result.failure
        render(:new, status: :unprocessable_entity)
      end
    end

    # PATCH /admin/versions/:id
    #
    # Shows or hides the version, or sets its release date.
    def update
      if version_params.key?(:released_on)
        saved = @version.update(released_on: version_params[:released_on])
        notice = t("admin.versions.released_on_saved", tag: @version.tag)
      else
        saved = @version.update(hidden: ActiveModel::Type::Boolean.new.cast(version_params[:hidden]))
        notice = t("admin.versions.#{@version.hidden ? 'hidden' : 'visible'}", tag: @version.tag)
      end

      if saved
        flash[:notice] = notice
      else
        flash[:alert] = @version.errors.full_messages.to_sentence
      end

      redirect_to(admin_versions_path)
    end

    # GET /admin/versions/:id/confirm_destroy
    def confirm_destroy
      render(:confirm_destroy, layout: "application")
    end

    # DELETE /admin/versions/:id
    #
    # Deletes the version with its OAuth applications, and with them their tokens and grants.
    def destroy
      Version.transaction do
        @version.oauth_applications.destroy_all
        @version.destroy!
      end

      flash[:notice] = t("admin.versions.destroyed", tag: @version.tag)
      redirect_to(admin_versions_path)
    end

    private

    # A version that has saved scenarios or collections, or is the default, is not found here.
    def check_deletable
      raise ActiveRecord::RecordNotFound unless @version.deletable?
    end

    def version_params
      params.require(:version).permit(:tag, :hidden, :released_on)
    end
  end
end
