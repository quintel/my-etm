# frozen_string_literal: true

module Api
  module V4
    # Saving from the API: the current Session becomes a Snapshot, and a clone of it becomes current
    class SnapshotsController < BaseController
      load_and_authorize_resource :saved_scenario

      before_action only: %i[create] do
        authorize!(:update, @saved_scenario)
      end

      before_action :reject_discarded_scenario

      # POST /api/v4/saved_scenarios/:saved_scenario_id/snapshots
      def create
        render_write(snapshot, with: SavedScenarioSerialiser, status: :created)
      end

      private

      def snapshot
        client = engine_client(scenario: @saved_scenario)

        ApiScenario::Create.call(client, { scenario_id: @saved_scenario.scenario_id }).bind do |clone|
          SavedScenario::UpsertScenario.call(client, @saved_scenario, clone["id"], user: current_user)
        end
      end

      def request_members
        []
      end
    end
  end
end
