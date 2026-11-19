# frozen_string_literal: true

module Identity
  module TokenMailerHelper
    def token_permissions(token)
      permissions = [
        [ "Read scenarios", "scenarios:read" ],
        [ "Write scenarios", "scenarios:write" ],
        [ "Delete scenarios", "scenarios:delete" ]
      ]

      permissions
        .select { |_, scope| token.scopes.include?(scope) }
        .map { |permission, _| "- #{permission}" }
        .join("</br>")
    end
  end
end
