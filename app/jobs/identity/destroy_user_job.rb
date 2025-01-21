# frozen_string_literal: true

# Permanently deletes a user.
class Identity::DestroyUserJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)

    Version.all.each do |version|
      MyEtm::Auth.model_client(user, version).delete("/api/v1/user") if Settings.etmodel.uri
      MyEtm::Auth.engine_client(user, version).delete("/api/v3/user") if Settings.etengine.uri
    end
    # Personal access tokens must be deleted before the access tokens, otherwise the destroy will
    # fail due to a foreign key constraint.
    user.personal_access_tokens.delete_all
    user.destroy

    true
  end
end
