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
        result = CreateSavedScenarioUser.call(
          engine_client,
          @saved_scenario,
          current_user.name,
          bulk_user_params,
          user: current_user
        )

        if result.successful?
          @saved_scenario.reload
          render json: result.value, status: :created
        else
          errors = normalize_errors(result)

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
        result = UpdateSavedScenarioUser.call(
          engine_client,
          @saved_scenario,
          bulk_user_params,
          nil,
          user: current_user
        )

        if result.successful?
          @saved_scenario.reload
          render json: result.value, status: :ok
        else
          errors = normalize_errors(result)
          status = errors_include_not_found?(result) ? :not_found : :unprocessable_entity

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
        result = DestroySavedScenarioUser.call(
          engine_client,
          @saved_scenario,
          bulk_user_params,
          user: current_user
        )

        if result.successful?
          render json: legacy_destroyed_users(result), status: :ok
        else
          errors = normalize_errors(result)

          # Partial success: return both successes and errors
          if result.value.present?
            render json: { success: legacy_destroyed_users(result), errors: errors },
              status: :unprocessable_entity
          else
            render json: { errors: errors }, status: :unprocessable_entity
          end
        end
      end

      private

      # V1's error body is a hash keyed by whichever identifier the caller sent. Two
      # items sharing one identifier collapse into a single entry. Kept as-is for compatibility.
      def normalize_errors(result)
        return result.errors unless result.respond_to?(:items)

        result.items.reject(&:ok?).to_h { |item| [ item.identifier, item.messages ] }
      end

      # V1 answers destroy with the identifying fields of each removed member, rather than the record.
      def legacy_destroyed_users(result)
        Array(result.value).map do |saved_scenario_user|
          {
            user_id: saved_scenario_user.user_id,
            user_email: saved_scenario_user.user_email,
            role: User::ROLES[saved_scenario_user.role_id]
          }
        end
      end

      def errors_include_not_found?(result)
        return false unless result.respond_to?(:items)

        result.items.any? { |item| item.code == :not_found }
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
        role_sym = user_params.try(:[], :role).try(:to_sym)
        role_id = User::ROLES.key(role_sym)

        if role_id.nil? && role_sym.present?
          Rails.logger.warn(
            "Failed to find role_id for role: #{role_sym.inspect}. " \
            "Valid roles: #{User::ROLES.values.inspect}"
          )
        end

        {
          id: user_params[:id]&.to_i,
          role_id: role_id,
          user_id: user&.id,
          user_email: user&.email || user_params.try(:[], :user_email)
        }
      end

      def engine_client
        MyEtm::Auth.engine_client(
          current_user,
          @saved_scenario.version,
          scopes: current_scopes
        )
      end
    end
  end
end
