# frozen_string_literal: true

module Api
  module V2
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

      # GET /api/v2/saved_scenarios
      #
      # The caller's own scenarios, then filtered by the ability.
      # TODO: unpaginated.
      def index
        scenarios = current_user.saved_scenarios
          .accessible_by(current_ability)
          .kept
          .includes(:version)
          .with_rich_text_description
          .order(updated_at: :desc)

        render_collection(scenarios, with: SavedScenarioSerialiser)
      end

      # GET /api/v2/saved_scenarios/:id
      def show
        render_resource(@saved_scenario, with: SavedScenarioSerialiser)
      end

      # POST /api/v2/saved_scenarios
      def create
        attributes = validated(SavedScenarioCreateContract, create_params)
        return if attributes.nil?

        render_write(
          SavedScenario::Create.call(nil, attributes.stringify_keys, current_user),
          with: SavedScenarioSerialiser,
          status: :created
        )
      end

      # PUT/PATCH /api/v2/saved_scenarios/:id
      def update
        attributes = validated(SavedScenarioUpdateContract, update_params)
        return if attributes.nil?

        render_write(
          SavedScenario::Update.call(nil, @saved_scenario, attributes),
          with: SavedScenarioSerialiser
        )
      end

      # DELETE /api/v2/saved_scenarios/:id
      def destroy
        return render_validation_errors(@saved_scenario.errors) unless @saved_scenario.destroy

        render_no_content
      end

      # PUT /api/v2/saved_scenarios/:id/discard
      def discard
        @saved_scenario.discard

        render_resource(@saved_scenario, with: SavedScenarioSerialiser)
      end

      # PUT /api/v2/saved_scenarios/:id/restore
      def restore
        @saved_scenario.undiscard

        render_resource(@saved_scenario, with: SavedScenarioSerialiser)
      end

      private

      # Renders and returns nil when the contract rejects a member
      def validated(contract, attributes)
        result = contract.new.call(attributes.to_h.symbolize_keys)
        return result.to_h if result.success?

        render_validation_errors(result.errors.to_h)
        nil
      end

      def request_members
        %i[scenario_id title version description area_code end_year private]
      end

      def create_params
        resource_params(:scenario_id, :title, :version, :description, :area_code, :end_year, :private)
      end

      def update_params
        resource_params(:title, :description, :area_code, :end_year, :private)
      end
    end
  end
end
