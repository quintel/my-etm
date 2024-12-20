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
    version_tags_result = ApiScenario::VersionTags::FetchAll.call(engine_client, @saved_scenario)

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
      engine_client,
      params[:scenario_id],
      update_params[:description]
    )

    if result.successful?
      respond_to do |format|
        format.json { render json: result.value }
      end
    else
      respond_to do |format|
        format.json { render json: result.errors }
      end
    end
  end

  # TODO: check if restore is better here or on SavedScenario
  # Here might be easier to remove with turbo from frame/view

  private

  def update_params
    params.permit(:description)
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
end
