# frozen_string_literal: true

module Identity
  module IdentityController
    extend ActiveSupport::Concern

    included do
      before_action :authenticate_user!
      before_action :set_back_url
    end

    private

    def set_back_url
      return unless params[:client_id]

      app = OAuthApplication.find_by(uid: params[:client_id])
      session[:back_to_etm_url] = app.uri if app&.uri && app&.first_party?
    end
  end
end
