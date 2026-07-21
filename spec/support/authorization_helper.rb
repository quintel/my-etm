# frozen_string_literal: true

module AuthorizationHelper
  def access_token_header(user, scopes, expires_in: 1.hour)
    user = create(:user) unless user&.persisted?

    scopes =
      case scopes
      when :public
        'public'
      when :read
        'public scenarios:read'
      when :write
        'public scenarios:read scenarios:write'
      when :delete
        'public scenarios:read scenarios:write scenarios:delete'
      else
        if scopes.is_a?(Symbol)
          raise "Unknown scope alias #{scopes.inspect}, expected :public, :read, :write, " \
                ':delete or a string'
        end

        scopes.to_s
      end

    token = create(:access_token, resource_owner_id: user.id, scopes:, expires_in: expires_in.to_i)
    { 'Authorization' => "Bearer #{token.token}" }
  end

  # Bearer header carrying a self-signed JWT that is NOT stored as a Doorkeeper token — exercises
  # Api::V1::BaseController's local JWT-verification fallback (MyEtm::Auth.verify_jwt), the path used
  # when a token can't be resolved by value (e.g. after refresh-token rotation).
  # Bearer header carrying a self-issued session JWT, minted with the full claim contract that
  # MyEtm::Auth.verify_jwt enforces: issuer, an audience including MyETM, subject and expiry.
  def session_token_header(user, scopes: 'public scenarios:read scenarios:write')
    key = MyEtm::Auth.signing_key
    jwt = JWT.encode(
      {
        iss: Settings.auth.issuer,
        aud: [Settings.auth.issuer],
        sub: user.id,
        scopes: scopes.split,
        exp: 1.hour.from_now.to_i
      },
      key, 'RS256', kid: key.to_jwk['kid']
    )
    { 'Authorization' => "Bearer #{jwt}" }
  end

  # Bearer header carrying the real shared-session JWT: a genuine Doorkeeper access token's own
  # `.token` value, exactly as JwtSessionCookies mints it — exercises doorkeeper_token resolving the
  # session cookie's value directly (the DB-backed path, not the JWT-verification fallback above).
  def shared_session_token_header(user, scopes: JwtSessionCookies::SESSION_SCOPES)
    token = user.access_tokens.create!(expires_in: 10.minutes, scopes: scopes, use_refresh_token: true)
    { 'Authorization' => "Bearer #{token.token}" }
  end

  def stub_faraday_422(body)
    faraday_response = instance_double(Faraday::Response)
    allow(faraday_response).to receive(:[]).with(:body).and_return('errors' => body)

    Faraday::UnprocessableEntityError.new(nil, faraday_response)
  end
end
