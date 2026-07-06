# frozen_string_literal: true

# ApplicationController#current_user now reads the shared JWT session cookie, not Warden — but
# Devise's own Test::ControllerHelpers/IntegrationHelpers `sign_in` only sets up Warden's session
# (it doesn't POST a real login, so no cookie is ever minted). Wrapping `sign_in` here keeps that
# stubbed shortcut working without every spec needing to know about the cookie.
module AuthenticatedSessionHelper
  def sign_in(resource, *args, **kwargs)
    super
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(resource)
  end
end
