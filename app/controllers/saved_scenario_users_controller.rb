# frozen_string_literal: true

# The controller that handles calls to collections of SavedScenarioUsers
# for a given SavedScenario.
class SavedScenarioUsersController < ApplicationController
  before_action :assign_saved_scenario
  before_action :assign_saved_scenario_user, only: %i[update confirm_destroy destroy show]

  # Owners are the only ones with destroy rights.
  before_action do
    authorize!(:destroy, @saved_scenario)
  end

  # Render a page with a table showing all SavedScenarioUsers for a SavedScenario.
  #
  # GET /saved_scenarios/:saved_scenario_id/users
  def index
    respond_to do |format|
      format.html
    end
  end

  # Renders a form for adding a user to a given SavedScenario with a specific role.
  #
  # GET /saved_scenarios/:saved_scenario_id/users/new
  def new
    @saved_scenario_user = SavedScenarioUser.new(
      saved_scenario_id: @saved_scenario.id
    )

    render 'new', layout: 'application'
  end

  # Creates a new SavedScenarioUser for the given SavedScenario.
  # Renders the updated user-table on success or a flash message on failure.
  #
  # POST /saved_scenarios/:saved_scenario_id/users
  def create
    result = CreateSavedScenarioUser.call(
      engine_client, @saved_scenario, current_user.name, scenario_user_params
    )

    if result.successful?
      @saved_scenario_user = result.value
      @saved_scenario.reload

      flash.notice = "#{@saved_scenario_user.email} was succesfully added"

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_remove_modal, turbo_append_user, turbo_notice
          ]
        end
      end
    else
      flash[:alert] =
        t("saved_scenario_users.errors.#{result.errors.first}") ||
        "#{t('saved_scenario_users.errors.create')} #{t('saved_scenario_users.errors.general')}"

      @saved_scenario_user = SavedScenarioUser.new(scenario_user_params)
      render(:new, status: :unprocessable_entity)
    end
  end

  # Updates an existing SavedScenarioUser for this SavedScenario.
  # Renders the updated user-table on success or a flash message on failure.
  #
  # Currently it is only possible to update a user's role (role_id).
  #
  # PUT /saved_scenarios/:saved_scenario_id/users/:id
  def update
    result = UpdateSavedScenarioUser.call(
      engine_client,
      @saved_scenario,
      @saved_scenario_user,
      scenario_user_params[:role_id]&.to_i
    )

    if result.successful?
      @saved_scenario.reload

      # TODO: Responds with new table, but this is picked up nowhere
      respond_to do |format|

      end
    else
      flash[:alert] = t("scenario.users.errors.#{result.errors.first}") ||
        "#{t('scenario.users.errors.update')} #{t('scenario.users.errors.general')}"

      respond_to do |format|
        format.js { render 'flash', layout: false }
      end
    end
  end

  # Shows a form asking for confirmation on destroying a SavedScenarioUser.
  #
  # GET /saved_scenarios/:saved_scenario_id/users/:id/confirm_destroy
  def confirm_destroy
    render 'confirm_destroy',  layout: 'application'
  end

  # Destroys an existing SavedScenarioUser for this SavedScenario.
  # Renders the updated user-table on success or a flash message on failure.
  #
  # PUT /saved_scenarios/:saved_scenario_id/users/:id
  def destroy
    result = DestroySavedScenarioUser.call(engine_client, @saved_scenario, @saved_scenario_user)

    if result.successful?
      @saved_scenario.reload
      flash.notice = "Access was succesfully revoked"

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_remove_modal,
            turbo_stream.remove("saved_scenario_user_#{@saved_scenario_user.id}"),
            turbo_notice
          ]
        end
      end
    else
      puts result.errors
      flash[:alert] = "#{t('saved_scenario_users.errors.destroy')} #{t('saved_scenario_users.errors.general')}"

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_alert
        end
      end
    end
  end

  private

  def scenario_user_params
    permitted_params[:saved_scenario_user]
  end

  def permitted_params
    params.permit(
      :saved_scenario_id,
      :id,
      :role_id,
      saved_scenario_user: %i[user_id user_email role_id]
    )
  end

  def assign_saved_scenario
    @saved_scenario = SavedScenario.find(permitted_params[:saved_scenario_id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def assign_saved_scenario_user
    @saved_scenario_user = @saved_scenario.saved_scenario_users.find(permitted_params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to saved_scenario_users_path, notice: 'Something went wrong'
  end

  def turbo_append_user
    turbo_stream.append(
      "saved_scenario_users_table",
      SavedScenarioUser::UserRow::Component.new(
        user: @saved_scenario_user,
        destroy_path: confirm_destroy_saved_scenario_user_path(id: @saved_scenario_user.id),
        confirmed: !@saved_scenario_user.pending?,
        destroyable: !(@saved_scenario_user.role == :scenario_owner && @saved_scenario.single_owner?)
      )
    )
  end

  def turbo_remove_modal
    turbo_stream.update(:modal, "")
  end
end
