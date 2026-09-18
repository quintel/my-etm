# frozen_string_literal: true

module Api
  module V2
    class SavedScenarioUsersController < BaseController
      load_and_authorize_resource :saved_scenario, only: %i[create update destroy]

      before_action only: %i[create update destroy] do
        authorize!(:manage_members, @saved_scenario)
      end

      before_action :reject_discarded_scenario, only: %i[create]

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

      def apply(&service)
        submitted = submitted_items
        return if reject_item_ids(submitted)

        authorisation = SavedScenarioMemberAuthorisation.new(
          @saved_scenario, submitted.map { |item| scenario_user_params(item) },
          permit_owners: can?(:manage_owners, @saved_scenario)
        )

        render_users(authorisation.apply(&service))
      end

      def reject_item_ids(submitted)
        return false unless action_name == "create"

        index = submitted.index { |item| item[:id].present? }
        return false if index.nil?

        render_error(
          status: :bad_request,
          code: EtmApi::Errors::Codes::PARAM_INVALID,
          detail: "cannot be set when granting access",
          source: { pointer: "/saved_scenario_users/#{index}/id" }
        )
        true
      end

      def render_users(result)
        render_batch(
          result,
          with: SavedScenarioUserSerialiser,
          options: { emails: true },
          pointer: "/saved_scenario_users"
        )
      end

      def request_members
        %i[saved_scenario_users]
      end

      def submitted_items
        batch_params(:saved_scenario_users, permit: %i[id role user_id user_email])
      end

      def scenario_user_params(user_params)
        {
          id: user_params[:id]&.to_i,
          role_id: User::Roles.index_of(user_params[:role].to_s.presence&.to_sym),
          user_id: user_params[:user_id].presence&.to_i,
          user_email: user_params[:user_email]
        }
      end
    end
  end
end
