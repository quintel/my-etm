# frozen_string_literal: true

module Api
  module V1
    class SavedScenarioUsersController < BaseController
      check_authorization

      load_and_authorize_resource :saved_scenario

      before_action only: %i[index] do
        # For privacy reasons we dont share the emails of all attached users
        authorize!(:update, SavedScenario)
      end

      def index
        render json: @saved_scenario.saved_scenario_users
      end

      def create
        result = SavedScenarioUsers::Create.call(
          engine_client,
          @saved_scenario,
          bulk_user_params,
          current_user.name,
          current_user
        )

        if result.successful?
          @saved_scenario.reload
          render json: result.value, status: :created
        else
          errors = result.errors

          # Partial success: return both successes and errors
          if result.value.present?
            @saved_scenario.reload
            render json: { success: result.value, errors: errors }, status: :unprocessable_entity
          else
            render json: { errors: errors }, status: :unprocessable_entity
          end
        end
      end

      def update
        result = SavedScenarioUsers::Update.call(
          engine_client,
          @saved_scenario,
          bulk_user_params,
          current_user
        )

        if result.successful?
          @saved_scenario.reload
          render json: result.value, status: :ok
        else
          errors = result.errors
          status = errors_include_not_found?(errors) ? :not_found : :unprocessable_entity

          # Partial success: return both successes and errors
          if result.value.present?
            @saved_scenario.reload
            render json: { success: result.value, errors: errors }, status: status
          else
            render json: { errors: errors }, status: status
          end
        end
      end

      def destroy
        result = SavedScenarioUsers::Destroy.call(
          engine_client,
          @saved_scenario,
          bulk_user_params,
          current_user
        )

        if result.successful?
          render json: result.value, status: :ok
        else
          errors = result.errors

          # Partial success: return both successes and errors
          if result.value.present?
            render json: { success: result.value, errors: errors }, status: :unprocessable_entity
          else
            render json: { errors: errors }, status: :unprocessable_entity
          end
        end
      end

      private

      def errors_include_not_found?(errors)
        return false unless errors.is_a?(Hash) || errors.is_a?(Array)

        errors_str = errors.to_s.downcase
        errors_str.include?("not found")
      end

      def permitted_params
        params.permit(:saved_scenario_id, saved_scenario_users: [ %i[id role user_id user_email] ])
      end

      def bulk_user_params
        return [] unless permitted_params[:saved_scenario_users]

        permitted_params[:saved_scenario_users].map do |user_params|
          scenario_user_params(user_params)
        end
      end

      def scenario_user_params(user_params)
        user = User.find(user_params[:user_id]) if user_params[:user_id].present?
        {
          id: user_params[:id]&.to_i,
          role_id: User::ROLES.key(user_params.try(:[], :role).try(:to_sym)),
          user_id: user&.id,
          user_email: user&.email || user_params.try(:[], :user_email)
        }
      end

      def engine_client
        MyEtm::Auth.engine_client(
          current_user,
          @saved_scenario.version,
          scopes: doorkeeper_token ? doorkeeper_token.scopes : []
        )
      end
    end
  end
end
