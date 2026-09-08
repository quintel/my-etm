# frozen_string_literal: true

module Admin
  class VersionsController < ApplicationController
    include AdminController

    # GET /admin/versions
    def index
      @versions = Version.all
    end
  end
end
