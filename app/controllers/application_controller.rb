class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps,
  # CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Returns the Faraday client which should be used to communicate with ETEngine. This contains the
  # user authentication token if the user is logged in.
  def engine_client
    # if current_user
    #   identity_session.access_token.http_client
    # else
    #   Identity.http_client
    # end
  end
end
