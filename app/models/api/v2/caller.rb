# frozen_string_literal: true

module Api
  module V2
    # Represents the authenticated caller of a v2 API request.
    #
    # Whether the request is authenticated with a session cookie or a personal
    # access token, we reduce it to the same object: the authenticated user and
    # the scopes they are allowed to use.
    #
    # Returns nil for a credential that does not authenticate; the caller decides what that means.
    Caller = Data.define(:user, :scopes) do

      # The shared session cookie, verified locally against MyETM's own signing key — the
      # same self-contained-JWT path every other ETM app uses.
      def self.from_cookie(jwt)
        claims = jwt.present? ? MyEtm::Auth.verify_jwt(jwt) : nil

        claims && build(User.find_by(id: claims["sub"]), claims["scopes"])
      end

      # A personal access token. The stored record is authoritative for liveness and scopes;
      # `accessible?` makes a revoked PAT stop working on the very next request.
      def self.from_bearer(credential)
        token = Doorkeeper::AccessToken.by_token(credential)
        return nil unless token&.accessible?

        build(User.find_by(id: token.resource_owner_id), token.scopes)
      end

      private
      # A JWT carries scopes as one space-delimited string, a Doorkeeper record as a scopes object.
      # Both become a list, so a scope check is a membership test and not a substring match.
      def self.build(user, scopes)
        user && new(user:, scopes: scopes.is_a?(String) ? scopes.split : Array(scopes))
      end
    end
  end
end
