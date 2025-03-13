# frozen_string_literal: true

# Controller that fetches and updates the scenario versions underlying a saved scenario
class SavedScenarioHistoryController < ApplicationController
  before_action :assign_saved_scenario
  before_action :authorize_saved_scenario_update, only: %i[index update]
  helper_method :editable_saved_scenario?

  # GET /saved_scenarios/:saved_scenario_id/history
  def index
    fetch_history
    render "index"
  end

  # PUT /saved_scenarios/:saved_scenario_id/history/:scenario_id
  def update
    result = ApiScenario::VersionTags::Update.call(
      engine_client(@saved_scenario.version),
      params[:scenario_id],
      update_params[:description]
    )
    if result.successful?
      historical_version = present_history_for_update(result)
      respond_with_turbo_stream(turbo_update_component(historical_version))
    else
      flash[:alert] = t("saved_scenario_history.error")
      respond_with_turbo_stream(turbo_alert)
    end
  end

  # RESTORE a saved scenario to a previous version
  def restore
    old_history_ids = discarded_scenario_ids
    result = SavedScenario::Restore.call(
      engine_client(@saved_scenario.version),
      @saved_scenario,
      params[:scenario_id].to_i
    )
    if result.successful?
      respond_with_turbo_stream(turbo_remove_components(old_history_ids))
    else
      flash[:alert] = t("saved_scenario_history.error")
      respond_with_turbo_stream(turbo_alert)
    end
  end

  private

  def update_params
    params.require(:saved_scenario_history).permit(:description)
  end

  # Fetch version tags and present the history
  def fetch_history
    version_tags_result = ApiScenario::VersionTags::FetchAll.call(
      engine_client(@saved_scenario.version),
      @saved_scenario
    )
    @history = if version_tags_result.successful?
                 SavedScenarioHistoryPresenter.present(@saved_scenario, version_tags_result.value)
    else
                 {}
    end
  end

  # Present history for a single update request
  def present_history_for_update(result)
    SavedScenarioHistoryPresenter.present(
      @saved_scenario,
      { params[:scenario_id] => result.value }
    ).first
  end

  def assign_saved_scenario
    @saved_scenario = SavedScenario.find(params[:saved_scenario_id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def authorize_saved_scenario_update
    authorize!(:update, @saved_scenario)
  end

  # Compute an array of scenario IDs to remove from history after a restore
  def discarded_scenario_ids
    all_ids = @saved_scenario.all_scenario_ids
    index = all_ids.index(params[:scenario_id].to_i)
    (index && index < all_ids.size - 1) ? all_ids[(index + 1)..-1] : []
  end

  # Determines whether the SavedScenario is editable by the current_user
  def editable_saved_scenario?(saved_scenario = nil)
    saved_scenario ||= @saved_scenario
    saved_scenario.collaborator?(current_user) ||
      saved_scenario.owner?(current_user) ||
      current_user&.admin?
  end

  # --- Turbo Stream Helpers ---
  def respond_with_turbo_stream(stream)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: stream }
    end
  end

  def turbo_update_component(historical_version)
    turbo_stream.update(
      "scenario_#{historical_version.scenario_id}",
      history_component(historical_version)
    )
  end

  def turbo_remove_components(old_history_ids)
    old_history_ids.map { |scenario_id| turbo_stream.remove("scenario_#{scenario_id}") }
  end

  def turbo_alert
    turbo_stream.update(:alert, html: flash[:alert])
  end

  # Build the component for a history row
  def history_component(historical_version)
    History::Row::Component.new(
      historical_version: historical_version,
      tag: "scenario_#{historical_version.scenario_id}",
      update_path: saved_scenario_update_history_path(
        id: @saved_scenario.id,
        scenario_id: historical_version.scenario_id
      ),
      restore_path: saved_scenario_restore_history_path(
        id: @saved_scenario.id,
        scenario_id: historical_version.scenario_id
      ),
      owner: @saved_scenario.owner?(current_user),
      collaborator: @saved_scenario.collaborator?(current_user),
      restorable: @saved_scenario.scenario_id != historical_version.scenario_id
    )
  end

  def turbo_alert
    turbo_stream.update(:alert, html: flash[:alert])
  end
end
