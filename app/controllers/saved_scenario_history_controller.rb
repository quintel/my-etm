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

  # TODO: make this HTML / turbo
  # PUT /saved_scenarios/:id/history/:scenario_id
  def update
    result = ApiScenario::VersionTags::Update.call(
      engine_client(@saved_scenario.version),
      params[:scenario_id],
      update_params[:description]
    )

    if result.successful?
      puts params
      historical_version = SavedScenarioHistoryPresenter.present(
        @saved_scenario, { params[:scenario_id] => result.value }
      ).first

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [ turbo_update_component(historical_version) ]
        end
      end
    else
      respond_to do |format|
        format.turbo_stream { render json: result.errors }
      end
    end
  end

  # TODO: check if restore is better here or on SavedScenario
  # Here might be easier to remove with turbo from frame/view

  private

  def update_params
    params.require(:saved_scenario_history).permit(:description)
  end

  # We pass this around all of the time or we do it with js?
  def history_params
    params.permit(:user_name, :description)
  end

  def assign_saved_scenario
    @saved_scenario = SavedScenario.find(params[:saved_scenario_id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
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
      owner: @saved_scenario.owner?(current_user),
      collaborator: @saved_scenario.collaborator?(current_user)
    )
  end

  # Updates the turbo frame with the given tag with a new one
  def turbo_update_component(historical_version)
    turbo_stream.update(
      "scenario_#{historical_version.scenario_id}",
      history_component(historical_version)
    )
  end
end
