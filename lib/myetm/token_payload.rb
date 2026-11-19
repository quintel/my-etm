# frozen_string_literal: true

module MyEtm
  # The claims of every token MyETM signs
  class TokenPayload
    def initialize(user:, scopes:, application: nil, version: nil, expires_in: nil, scenario_access: nil)
      raise ArgumentError, "give an application or a Version, not both" if application && version

      @user = user
      @scopes = scopes
      @application = application
      @version = version
      @expires_in = expires_in
      @access = ScenarioAccess.new(scenario_access)
    end

    def to_h
      now = Time.now.to_i

      {
        iss: Doorkeeper::OpenidConnect.configuration.issuer.call(@user, nil),
        iat: now,
        aud: audience,
        scopes: @scopes,
        jti: SecureRandom.uuid,
        sub: @user.id,
        user: @user.as_json(only: %i[id admin email name])
      }.merge(optional_claims(now))
    end

    private

    def optional_claims(now)
      {
        exp: @expires_in && now + @expires_in,
        ScenarioAccess::CLAIM => (@access.as_claim unless @access.empty?)
      }.compact
    end

    def audience
      if @application then application_audience
      elsif @version then [ @version.engine_url ]
      elsif @scopes.to_s.split.include?("roles") then session_audience
      else personal_access_audience
      end
    end

    # Every app within the application's Version, plus MyETM.
    # TEMPORARY(engine-forwards-tokens): MyETM is here because ETEngine's v3 proxies forward the
    # caller's token to it verbatim (Api::V3::BaseController#my_etm_client). Drop it once they are gone.
    def application_audience
      @application.version.urls + [ Settings.auth.issuer ]
    end

    def session_audience
      Version.all.flat_map(&:urls).uniq + [ Settings.auth.issuer ]
    end

    # Every engine, not MyETM, so a leaked PAT cannot manage its user's tokens
    def personal_access_audience
      Version.all.map(&:engine_url)
    end
  end
end
