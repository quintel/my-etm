# frozen_string_literal: true

require 'myetm/auth'

Doorkeeper::OpenidConnect.configure do
  issuer do |_resource_owner, _application|
    Settings.auth.issuer
  end

  signing_key MyEtm::Auth.signing_key_content

  subject_types_supported [:public]

  resource_owner_from_access_token do |access_token|
    # Example implementation:
    User.find_by(id: access_token.resource_owner_id)
  end

  auth_time_from_resource_owner do |resource_owner|
    # Example implementation:
    resource_owner.current_sign_in_at
  end

  reauthenticate_resource_owner do |resource_owner, return_to|
    # Example implementation:
    store_location_for resource_owner, return_to
    sign_out resource_owner
    redirect_to new_user_session_url
  end

  # Depending on your configuration, a DoubleRenderError could be raised
  # if render/redirect_to is called at some point before this callback is executed.
  # To avoid the DoubleRenderError, you could add these two lines at the beginning
  #  of this callback: (Reference: https://github.com/rails/rails/issues/25106)
  #   self.response_body = nil
  #   @_response_body = nil
  select_account_for_resource_owner do |resource_owner, return_to|
    # Example implementation:
    # store_location_for resource_owner, return_to
    # redirect_to account_select_url
  end

  subject do |resource_owner, _application|
    # Example implementation:
    resource_owner.id

    # or if you need pairwise subject identifier, implement like below:
    # Digest::SHA256.hexdigest("#{resource_owner.id}#{URI.parse(application.redirect_uri).host}#{'your_secret_salt'}")
  end

  # Protocol to use when generating URIs for the discovery endpoint,
  # for example if you also use HTTPS in development
  protocol do
    Rails.env.development? ? :http : :https
  end

  # Expiration time on or after which the ID Token MUST NOT be accepted for processing. (default 120 seconds).
  # expiration 600

  end_session_endpoint do
    destroy_user_session_url
  end

  claims do
    # rubocop:disable Style/SymbolProc
    normal_claim(:email, response: %i[id_token user_info]) do |resource_owner|
      resource_owner.email
    end

    normal_claim(:roles, scope: :roles, response: %i[user_info]) do |resource_owner|
      resource_owner.roles
    end

    normal_claim(:name, scope: :profile, response: %i[id_token user_info]) do |resource_owner|
      resource_owner.name
    end
    # rubocop:enable Style/SymbolProc
  end
end
