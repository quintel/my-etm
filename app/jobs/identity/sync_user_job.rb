# frozen_string_literal: true

require "uri"
require "net/http"

# Syncs a user's identity with ETModel.
class Identity::SyncUserJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    return false unless Settings.etmodel.uri && Settings.etengine.uri

    user = User.find(user_id)

    MyEtm::Auth.model_client(user).put(
      "/api/v1/user",
      user.to_json(except: %i[admin created_at updated_at])
    )

    MyEtm::Auth.engine_client(user).put(
      "/api/v3/user",
      user.to_json(except: %i[admin created_at updated_at])
    )

    true
  end
end
