# frozen_string_literal: true

module Api
  module V2
    class SavedScenarioUsersController < BaseController
      load_and_authorize_resource :saved_scenario, only: %i[index create update destroy]

      before_action only: %i[index] do
        authorize!(:read_members, @saved_scenario)
      end

      # Managing access is owner-only, as it is in the UI, so it answers to the same rule as
      # destroying the scenario itself.
      before_action only: %i[create update destroy] do
        authorize!(:destroy, @saved_scenario)
      end

      before_action :reject_discarded_scenario, only: %i[create]

      # GET /api/v2/saved_scenarios/:saved_scenario_id/users
      #
      # Emails are served because only a caller who may manage access reaches this action. The id is
      # what the batch actions address a membership by, including one that is still an invitation.
      def index
        render_collection(
          @saved_scenario.saved_scenario_users.includes(:user).order(:id),
          with: SavedScenarioUserSerialiser
        )
      end

      # POST /api/v2/saved_scenarios/:saved_scenario_id/users
      def create
        apply(SavedScenarioUserContract) do |members|
          CreateSavedScenarioUser.call(
            nil, @saved_scenario, current_user.name, members,
            user: current_user, sync_to_engine: false
          )
        end
      end

      # PUT/PATCH /api/v2/saved_scenarios/:saved_scenario_id/users
      def update
        apply(SavedScenarioUserContract) do |members|
          UpdateSavedScenarioUser.call(
            nil, @saved_scenario, members, user: current_user, sync_to_engine: false
          )
        end
      end

      # DELETE /api/v2/saved_scenarios/:saved_scenario_id/users
      def destroy
        apply(SavedScenarioUserRemovalContract) do |members|
          DestroySavedScenarioUser.call(
            nil, @saved_scenario, members, user: current_user, sync_to_engine: false
          )
        end
      end

      private

      def reject_discarded_scenario
        return unless @saved_scenario.discarded?

        render_error(
          status: :conflict,
          code: EtmApi::Errors::Codes::SCENARIO_DISCARDED,
          detail: "Saved scenario is discarded"
        )
      end

      # An item the contract refuses never reaches the service, and is reported at the position it
      # was submitted at, beside the results of the items that did.
      def apply(contract)
        accepted, refused = read_items(contract)
        applied = accepted.any? ? yield(accepted.map { |_, item| scenario_user_params(item) }) : nil

        attempted = at_submitted_positions(applied, accepted.map(&:first))
        render_users(BulkResult.new((refused + attempted).sort_by(&:index)))
      end

      # Every item keeps the position it arrived at, so a refusal and a result are addressed alike
      # however few items the service was given. Returns the accepted items first, then the refusals.
      def read_items(contract)
        accepted = []
        refused = []

        submitted_items.each_with_index do |item, index|
          result = contract.new.call(item.to_h.symbolize_keys)

          if result.success?
            accepted << [ index, result.to_h ]
          else
            refused << refusal(index, item, result)
          end
        end

        [ accepted, refused ]
      end

      def refusal(index, item, result)
        BulkResult::Item.error(
          index: index,
          identifier: item[:email],
          code: :validation_failed,
          messages: result.errors.map { |error| "#{error.path.join('/')} #{error.text}" }
        )
      end

      # A service numbers the list it was handed, which holds only the accepted items, so each
      # result is moved back onto the position its item was submitted at.
      def at_submitted_positions(applied, positions)
        return [] if applied.nil?

        applied.items.map { |item| item.with(index: positions[item.index]) }
      end

      def render_users(result)
        render_batch(
          result,
          with: SavedScenarioUserSerialiser,
          pointer: "/saved_scenario_users"
        )
      end

      def request_members
        %i[saved_scenario_users]
      end

      # The default read-only set is a resource's; an item here carries only what it is told, and
      # `pending` is the one thing a caller can send back having fetched it.
      def readonly_members
        %i[pending]
      end

      def submitted_items
        batch_params(:saved_scenario_users, permit: %i[role email])
      end

      def scenario_user_params(user_params)
        {
          role_id: User::Roles.index_of(user_params[:role].to_s.presence&.to_sym),
          user_email: user_params[:email]
        }
      end
    end
  end
end
