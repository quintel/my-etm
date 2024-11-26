# frozen_string_literal: true

class CollectionsController < ApplicationController

  load_resource only: %i[show discard undiscard]

  before_action :ensure_valid_config

  before_action except: %i[show discard undiscard] do
    authenticate_user!(show_as: :sign_in)
  end

  before_action only: %i[discard undiscard] do
    authorize!(:destroy, @multi_year_chart)
  end


  # DONE
#   Public Methods (Actions)
# 	1.	index - GET /collections or /collections.json


  # TODO - finish other methods, rest are just copied untested from Model
    # DONE
#   Public Methods (Actions)
# 	1.	index - GET /collections or /collections.json

    # In progress
# 	2.	create - POST /collections or /collections.json


  # GET /collections or /collections.json
  def index
    # Include Pagy to paginate @collections or any other resource
    @pagy_collections, @collections = pagy(user_collections)
    @pagy_scenarios, @saved_scenarios = pagy(user_saved_scenarios)

    respond_to do |format|
      format.html
      format.js do
        render(params[:wants] == 'scenarios' ? 'scenarios' : 'index')
      end
    end
  end

  def new
    @multi_year_chart = current_user.multi_year_charts.build(interpolation: false)

    respond_to do |format|
      format.html { render layout: 'application' }
    end
  end

  # Part of the My Scenarios view, lists all MYC that are not discarded
  #
  # GET multi_year_charts/list
  def list
    @multi_year_charts = user_collections
      .kept
      .includes(:user)

    respond_to do |format|
      format.html { render layout: 'application' }
    end
  end

  def show
    respond_to do |format|
      format.html { render layout: 'application' }
    end
  end

  # Creates a new MultiYearChart record based on the scenario specified in the
  # params. This is the interpolation route
  #
  # Redirects to the external MYC app when successful.
  #
  # POST /multi_year_charts
  def create
    result = CreateCollection.call(
      MyEtm::Auth.engine_client(current_user),
      current_user.saved_scenarios.find(params.require(:scenario_id)), # TODO double check this
      current_user
    )

    if result.successful?
      redirect_to helpers.myc_url(result.value), allow_other_host: true
    else
      flash.now[:error] = result.errors.join(', ')

      @scenarios = user_scenarios
      @multi_year_charts = user_multi_year_charts

      render :index, status: :unprocessable_entity
    end
  end

  def create_collection
    saved_scenario_ids = create_collection_params.delete(:saved_scenarios)

    collection = current_user.multi_year_charts.build(
      title: collection_title,
      interpolation: false
    )

    saved_scenario_ids.uniq.reject(&:empty?).each do |saved_scenario_id|
      collection.multi_year_chart_saved_scenarios.build(saved_scenario_id:)
    end

    if collection.valid?
      collection.save
      redirect_to show_multi_year_chart_path(collection)
    else
      flash[:error] = t('multi_year_charts.failure')
      redirect_to list_multi_year_charts_path
    end
  end

  # Removes a MultiYearChart record.
  #
  # DELETE /multi_year_charts/:id
  def destroy
    DeleteMultiYearChart.call(
      engine_client,
      current_user.multi_year_charts.find(params.require(:id))
    )

    redirect_to multi_year_charts_path
  end

  # Soft-deletes the myc so that it no longer appears in listings.
  #
  # PUT /multi_year_charts/:id/discard
  def discard
    unless @multi_year_chart.discarded?
      @multi_year_chart.discarded_at = Time.zone.now
      @multi_year_chart.save(touch: false)

      flash.notice = t('scenario.trash.discarded_flash')
      flash[:undo_params] = [undiscard_multi_year_chart_path(@multi_year_chart), { method: :put }]
    end

    redirect_back(fallback_location: list_multi_year_charts_path)
  end

  # Removes the soft-deletes of the scenario.
  #
  # PUT /multi_year_charts/:id/undiscard
  def undiscard
    unless @multi_year_chart.kept?
      @multi_year_chart.discarded_at = nil
      @multi_year_chart.save(touch: false)

      flash.notice = t('scenario.trash.undiscarded_flash')
      flash[:undo_params] = [discard_multi_year_chart_path(@multi_year_chart), { method: :put }]
    end

    redirect_back(fallback_location: discarded_saved_scenarios_path)
  end

  private

  def user_saved_scenarios
    return [] unless current_user

    # Fetch saved scenarios where the user has any role (viewer, collaborator, or owner)
    scenarios = current_user
      .saved_scenarios
      .order('created_at DESC') # Order by most recent first

    scenarios
  end

  def user_collections
    return [] unless current_user

    current_user
      .collections
      .order(created_at: :desc)
  end

  def ensure_valid_config
    return if Settings.collections_url

    redirect_to root_path,
      notice: 'Missing collections_url setting in config.yml'
  end

  def create_collection_params
    params.require(:multi_year_chart).permit(:title, saved_scenarios: [])
  end

  def collection_title
    title = create_collection_params[:title]
    title.empty? ? t('multi_year_charts.no_title') : title
  end
end
