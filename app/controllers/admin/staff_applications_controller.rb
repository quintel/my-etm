# frozen_string_literal: true

module Admin
  # Updates a staff application with a new URI.
  class StaffApplicationsController < ApplicationController
    include AdminController

    # Shows all staff applications that have been setup
    def index

    end


    def update
      result = CreateStaffApplication.call(
        current_user,
        MyEtm::StaffApplications.find(params[:id]),
        uri: params[:uri].presence
      )

      if result.success?
        flash[:notice] = 'The application was updated.'
      else
        flash[:alert] = result.failure.errors.full_messages.to_sentence
      end

      redirect_to admin_applications_path
    end
  end
end
