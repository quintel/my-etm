# frozen_string_literal: true

module Api
  module V4
    class SavedScenariosController < BaseController
      self.resource_param_key = :saved_scenario

      before_action :require_user, only: %i[index]

      load_and_authorize_resource(
        class: SavedScenario, only: %i[show update destroy discard restore]
      )

      authorize_resource(class: SavedScenario, only: %i[index])

      before_action only: %i[create] do
        authorize!(:create, SavedScenario)
      end

      # GET /api/v4/saved_scenarios
      #
      # The caller's own scenarios, then filtered by the ability.
      def index
        page, scenarios = paginated(
          current_user.saved_scenarios
            .accessible_by(current_ability)
            .kept
            .includes(:version)
            .with_rich_text_description
            .order(updated_at: :desc)
        )

        render_collection(scenarios, with: SavedScenarioSerialiser, meta: pagination_meta(page))
      end

      # GET /api/v4/saved_scenarios/:id
      def show
        render_resource(@saved_scenario, with: SavedScenarioSerialiser)
      end

      # POST /api/v4/saved_scenarios
      def create
        attributes = validated(SavedScenarioCreateContract, create_params)
        return if attributes.nil?

        source = readable_source(attributes)
        reject_discarded_scenario(source) if source
        return if performed?

        render_write(create_saved_scenario(attributes, source), with: SavedScenarioSerialiser, status: :created)
      end

      # PUT/PATCH /api/v4/saved_scenarios/:id
      def update
        attributes = validated(SavedScenarioUpdateContract, update_params)
        return if attributes.nil?

        updated = SavedScenario::Update.call(
          engine_client(scenario: @saved_scenario), @saved_scenario, attributes, user: current_user
        )

        render_write(updated, with: SavedScenarioSerialiser)
      end

      # DELETE /api/v4/saved_scenarios/:id
      def destroy
        purged = SavedScenario::Purge.call(@saved_scenario, current_user)
        return render_write(purged, with: SavedScenarioSerialiser) if purged.failure?

        render_no_content
      end

      # PUT /api/v4/saved_scenarios/:id/discard
      def discard
        @saved_scenario.discard

        render_resource(@saved_scenario, with: SavedScenarioSerialiser)
      end

      # PUT /api/v4/saved_scenarios/:id/restore
      def restore
        @saved_scenario.undiscard

        render_resource(@saved_scenario, with: SavedScenarioSerialiser)
      end

      private

      def request_members
        members_of(SavedScenarioCreateContract, SavedScenarioUpdateContract)
      end

      def create_params
        resource_params(:scenario_id, :source, :title, :version, :description, :area_code, :end_year, :private)
      end

      def create_saved_scenario(attributes, source)
        return SavedScenario::Create.call(nil, attributes, current_user) if attributes[:scenario_id]

        SavedScenario::CreateWithNewSession.call(
          session_client(attributes, source), current_user, attributes, source:
        )
      end

      # A copy lives on its source's Version, a fresh Session lives on the requested one
      def session_client(attributes, source)
        engine_client(scenario: source, version: source&.version || Version.find_by!(tag: attributes[:version]))
      end

      def readable_source(attributes)
        return unless attributes[:source]

        SavedScenario.find(attributes[:source]).tap do |source|
          authorize!(source.interpolates_to?(attributes[:end_year]) ? :interpolate : :read, source)
        end
      end

      def update_params
        resource_params(:title, :description, :private)
      end
    end
  end
end
