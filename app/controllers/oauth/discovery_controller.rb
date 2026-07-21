# frozen_string_literal: true

module OAuth
  # Publishes the JWKS at /oauth/discovery/keys, overriding Doorkeeper's own controller so that the
  # single signing key is advertised under two `kid`s.
  #
  # Consumers resolve a token's signing key by matching the `kid` in its header against this
  # document. MyETM has always signed with one key, but has named it two different ways: tokens
  # minted before the shared-cookie migration carry a hex-encoded RFC 7638 thumbprint (the `jwt`
  # gem's format, previously computed by hand in doorkeeper_jwt.rb), while this endpoint publishes
  # the base64url form (json-jwt's format, via Doorkeeper::OpenidConnect). That never mattered,
  # because the old per-app decoders took `keys.first` and ignored `kid` entirely — but
  # Identity::TokenDecoder matches on it properly, so without the legacy entry below every personal
  # access token issued before the cutover would fail to verify the moment this branch deploys.
  #
  # These are two names for one key, not two keys: same modulus, same exponent, same signatures.
  #
  # TEMPORARY, paired with the `.split` in Identity::TokenDecoder#verify_audience!. Both go
  # when the next major API break invalidates every pre-migration personal access token — a
  # forcing event, not a calendar date; PATs can be minted for up to 365 days, so any earlier
  # removal must be coordinated with a user-visible change. Removing #legacy_key and its call site
  # is the whole change. If the signing key is rotated before then, every pre-migration token dies
  # with it and this can go immediately.
  class DiscoveryController < Doorkeeper::OpenidConnect::DiscoveryController
    private

    def keys_response
      response = super
      { keys: response[:keys] + [legacy_key] }
    end

    # The same public key under the `kid` that pre-migration tokens carry in their header.
    def legacy_key
      JWT::JWK.new(MyEtm::Auth.signing_key.public_key)
        .export
        .merge(use: "sig", alg: Doorkeeper::OpenidConnect.signing_algorithm)
    end
  end
end
