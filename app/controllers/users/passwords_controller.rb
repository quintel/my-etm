# frozen_string_literal: true

module Users
  class PasswordsController < Devise::PasswordsController
    include JwtSessionCookies

    def update
      super { |resource| reset_jwt_sessions(resource) if resource.errors.empty? }
    end
  end
end
