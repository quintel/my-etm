# frozen_string_literal: true
require 'myetm/staff_applications'

module Admin
  # Updates a staff application with a new URI.
  class StaffApplicationsController < ApplicationController
    include AdminController

    def index
      @staff_applications = MyEtm::StaffApplications.all
    end


    def update
      result = CreateStaffApplication.call(
        current_user,
        MyEtm::StaffApplications.find(params[:format]),
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
