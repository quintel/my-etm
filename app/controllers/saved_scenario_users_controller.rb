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

    render "new", layout: "application"
  end

  # Creates a new SavedScenarioUser for the given SavedScenario.
  # Renders the updated user-table on success or a flash message on failure.
  #
  # POST /saved_scenarios/:saved_scenario_id/users
  def create
    result = CreateSavedScenarioUser.call(
      engine_client(@saved_scenario.version),
      @saved_scenario,
      current_user.name,
      scenario_user_params
    )

    if result.successful?
      @saved_scenario_user = result.value
      @saved_scenario.reload
      flash.notice = "#{@saved_scenario_user.email} was successfully added"
      respond_with_turbo([ turbo_remove_modal, turbo_append_user, turbo_notice ])
    else
      flash[:alert] = render_failure_message("create", result.errors.first)
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
      engine_client(@saved_scenario.version),
      @saved_scenario,
      @saved_scenario_user,
      scenario_user_params[:role_id]&.to_i
    )

    if result.successful?
      respond_with_turbo(turbo_stream.update(@saved_scenario_user, user_component))
    else
      flash[:alert] = render_failure_message("update", result.errors.first)
      respond_with_turbo([ turbo_alert, turbo_stream.update(@saved_scenario_user, user_component) ])
    end
  end

  # Shows a form asking for confirmation on destroying a SavedScenarioUser.
  #
  # GET /saved_scenarios/:saved_scenario_id/users/:id/confirm_destroy
  def confirm_destroy
    render "confirm_destroy",  layout: "application"
  end

  # Destroys an existing SavedScenarioUser for this SavedScenario.
  # Renders the updated user-table on success or a flash message on failure.
  #
  # PUT /saved_scenarios/:saved_scenario_id/users/:id
  def destroy
    result = DestroySavedScenarioUser.call(
      engine_client(@saved_scenario.version),
      @saved_scenario,
      @saved_scenario_user
    )

    if result.successful?
      @saved_scenario.reload
      flash.notice = "Access was successfully revoked"
      respond_with_turbo([
        turbo_remove_modal,
        turbo_stream.remove("saved_scenario_user_#{@saved_scenario_user.id}"),
        turbo_notice
      ])
    else
      flash[:alert] = render_failure_message("destroy")
      respond_with_turbo(turbo_alert)
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
    redirect_to saved_scenario_users_path, notice: "Something went wrong"
  end

  # Renders a turbo stream response with the given stream(s).
  def respond_with_turbo(response_stream)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: response_stream }
    end
  end

  # Constructs a failure message for a given action and optional error key.
  def render_failure_message(action, error_key = nil)
    if error_key.present?
      t("saved_scenario_users.errors.#{error_key}") ||
        "#{t("saved_scenario_users.errors.#{action}")} #{t('saved_scenario_users.errors.general')}"
    else
      "#{t("saved_scenario_users.errors.#{action}")} #{t('saved_scenario_users.errors.general')}"
    end
  end

  def turbo_append_user
    turbo_stream.append(
      "saved_scenario_users_table",
      user_component
    )
  end

  def user_component
    SavedScenarioUser::UserRow::Component.new(
      user: @saved_scenario_user,
      destroy_path: confirm_destroy_saved_scenario_user_path(id: @saved_scenario_user.id),
      update_path: saved_scenario_user_path(id: @saved_scenario_user.id),
      confirmed: !@saved_scenario_user.pending?,
      destroyable: !(@saved_scenario_user.role == :scenario_owner && @saved_scenario.single_owner?)
    )
  end

  def turbo_remove_modal
    turbo_stream.update(:modal, "")
  end

  def turbo_notice
    turbo_stream.update(:notice, html: flash.notice)
  end

  def turbo_alert
    turbo_stream.update(:alert, html: flash[:alert])
  end
end
