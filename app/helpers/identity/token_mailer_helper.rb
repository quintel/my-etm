# frozen_string_literal: true

module Identity
  module TokenMailerHelper
    def token_permissions(token)
      permissions = [
        [ "Read", "scenarios:read" ],
        [ "Write", "scenarios:write" ],
        [ "Delete", "scenarios:delete" ]
      ]

      permissions
        .select { |_, scope| token.scopes.include?(scope) }
        .map { |permission, _| "- #{permission}" }
        .join("</br>")
    end
  end
end
