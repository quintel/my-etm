# frozen_string_literal: true

# Controller that fetches and updates the scenario versions underlying a saved scenario
class SavedScenarioHistoryController < ApplicationController
  before_action :assign_saved_scenario

  before_action only: %i[index update] do
    authorize!(:update, @saved_scenario)
  end

  helper_method :editable_saved_scenario?

  # GET /saved_scenarios/:id/history
  def index
    version_tags_result = ApiScenario::VersionTags::FetchAll.call(
      engine_client(@saved_scenario.version),
      @saved_scenario
    )

    if version_tags_result.successful?
      @history = SavedScenarioHistoryPresenter.present(@saved_scenario, version_tags_result.value)

      respond_to do |format|
        format.html { render 'index' }
      end
    else
      @history = {}
      respond_to do |format|
        format.html { render 'index' }
      end
    end
  end

  # PUT /saved_scenarios/:id/history/:scenario_id
  def update
    result = ApiScenario::VersionTags::Update.call(
      engine_client(@saved_scenario.version),
      params[:scenario_id],
      update_params[:description]
    )

    if result.successful?
      historical_version = SavedScenarioHistoryPresenter.present(
        @saved_scenario, { params[:scenario_id] => result.value }
      ).first

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [ turbo_update_component(historical_version) ]
        end
      end
    else
      flash[:alert] = "#{t('saved_scenario_history.error')}"

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_alert
        end
      end
    end
  end

  # Restore a saved scenario to a previous version
  def restore
    # Save them now, because after the restore service they will be deleted
    old_history_ids = discarded_scenarios

    result = SavedScenario::Restore.call(
      engine_client(@saved_scenario.version),
      @saved_scenario,
      params[:scenario_id].to_i
    )

    if result.successful?
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_remove_components(old_history_ids)
        end
      end
    else
      flash[:alert] = "#{t('saved_scenario_history.error')}"

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_alert
        end
      end
    end
  end

  private

  def update_params
    params.require(:saved_scenario_history).permit(:description)
  end

  def assign_saved_scenario
    @saved_scenario = SavedScenario.find(params[:saved_scenario_id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def discarded_scenarios
    scenarios = @saved_scenario.all_scenario_ids
    discard_no = scenarios.index(params[:scenario_id].to_i)

    scenarios[discard_no + 1...]
  end

  # This determines whether the SavedScenario is editable by the current_user
  def editable_saved_scenario?(saved_scenario = nil)
    saved_scenario ||= @saved_scenario

    saved_scenario.collaborator?(current_user) ||
      saved_scenario.owner?(current_user) ||
      current_user&.admin?
  end

  # The component for a scenario history row
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

  # Updates the turbo frame with the given tag with a new one
  def turbo_update_component(historical_version)
    turbo_stream.update(
      "scenario_#{historical_version.scenario_id}",
      history_component(historical_version)
    )
  end

  def turbo_remove_components(old_history_ids)
    old_history_ids.map do |scenario_id|
      turbo_stream.remove("scenario_#{scenario_id}")
    end
  end
end
