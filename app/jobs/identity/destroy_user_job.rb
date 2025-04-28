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

    user.destroy

    true
  end
end
