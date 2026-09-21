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
        apply do |members|
          CreateSavedScenarioUser.call(
            nil, @saved_scenario, current_user.name, members,
            user: current_user, sync_to_engine: false
          )
        end
      end

      # PUT/PATCH /api/v2/saved_scenarios/:saved_scenario_id/users
      def update
        apply do |members|
          UpdateSavedScenarioUser.call(
            nil, @saved_scenario, members, user: current_user, sync_to_engine: false
          )
        end
      end

      # DELETE /api/v2/saved_scenarios/:saved_scenario_id/users
      def destroy
        apply do |members|
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

      def apply
        submitted = submitted_items
        return if reject_unaddressed_items(submitted)

        render_users(yield(submitted.map { |item| scenario_user_params(item) }))
      end

      # An item naming nobody addresses nothing. Left to the model it answers "Either user_id or
      # user_email should be present", naming members V2 does not have.
      #
      # TODO: drop once v1 and v3 retire; the services can then take an address and say so.
      def reject_unaddressed_items(submitted)
        index = submitted.index { |item| item[:email].blank? }
        return false if index.nil?

        render_error(
          status: :bad_request,
          code: EtmApi::Errors::Codes::PARAM_INVALID,
          detail: "is required to address a member",
          source: { pointer: "/saved_scenario_users/#{index}/email" }
        )
        true
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
