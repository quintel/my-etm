# frozen_string_literal: true

# Permanently deletes a user.
class Identity::DestroyUserJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    MyEtm::Auth.model_client(user).delete("/api/v1/user") if Settings.etmodel.uri # TODO: Handle stable versions??
    MyEtm::Auth.engine_client(user).delete("/api/v3/user") if Settings.etengine.uri

    # Personal access tokens must be deleted before the access tokens, otherwise the destroy will
    # fail due to a foreign key constraint.
    user.personal_access_tokens.delete_all
    user.destroy

    true
  end
end
