# frozen_string_literal: true

class CollectionsController < ApplicationController
  include Pagy::Backend
  include Filterable

  load_resource only: %i[discard undiscard new_transition create_transition confirm_destroy]
  load_and_authorize_resource only: %i[show new edit destroy update]

  before_action :require_user, only: %i[index create_collection new_transition create_transition]
  before_action :ensure_valid_config
  before_action :welcome_back

  before_action only: %i[discard undiscard confirm_destroy] do
    authorize!(:destroy, @collection)
  end

  # GET /collections or /collections.json
  def index
    @pagy_collections, @collections = pagy_countless(user_collections)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  # Renders a partial of collections based on turbo search and filters
  #
  # GET /collections/list
  def list
    filtered = filter!(Collection).kept.where(user: current_user)

    @pagy_collections, @collections = pagy(filtered)

    respond_to do |format|
      format.html { render(
        partial: "collections",
        locals: { collections: @collections, pagy_collections: @pagy_collections }
      ) }
      format.turbo_stream { render(:index) }
    end
  end

  # Create a new collection of saved scenarios
  #
  # GET /collections/new
  def new
    @collection = current_user.collections.build(interpolation: false)
    @scenarios = current_user.saved_scenarios.available.order(updated_at: :desc)

    respond_to do |format|
      format.html { render layout: "application" }
    end
  end

  # GET /collections/1/edit
  def edit
    @scenarios = current_user.saved_scenarios.available.where(version: @collection.version).order(updated_at: :desc)
  end

  def update
    respond_to do |format|
      if @collection.update_with_scenarios(update_collection_params)
        format.html { redirect_to @collection, notice: t("collections.succesful_update") }
        format.json { render json: @collection }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @collection.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # Create a new collection from an interpolation of a saved scenario
  #
  # GET /collections/new_transition
  def new_transition
    @saved_scenarios = elegible_scenarios
    @collection = new_transition_collection
  end

  def show
    @editable = @collection.user == current_user
    respond_to do |format|
      format.html { render layout: "application" }
    end
  end

  # Creates a new Collection record based on the scenario specified in the
  # params. This is the interpolation route
  #
  # Redirects to the external MYC app when successful.
  #
  # POST /collections/create_transition
  def create_transition
    saved_scenario = current_user.saved_scenarios.find(create_transition_params[:saved_scenario_ids])

    result = CreateInterpolatedCollection.call(
      engine_client(saved_scenario.version),
      saved_scenario,
      current_user
    )

    if result.successful?
      redirect_to collection_path(result.value)
    else
      flash[:alert] = result.errors.join(", ")
      @collection = new_transition_collection
      @saved_scenarios = elegible_scenarios

      render :new_transition, status: :unprocessable_entity
    end
  end

  def create_collection
    collection = current_user.collections.build(
      title: collection_title,
      version: create_collection_params[:version],
      interpolation: false
    )

    create_collection_params[:saved_scenario_ids].uniq.reject(&:empty?).each do |saved_scenario_id|
      collection.collection_saved_scenarios.build(saved_scenario_id:)
    end

    if collection.valid?
      collection.save
      redirect_to collection_path(collection)
    else
      flash[:alert] = t("collections.failure")
      redirect_to collections_path
    end
  end

  def confirm_destroy
    render :confirm_destroy, layout: "application"
  end

  # Removes a Collection record.
  #
  # DELETE /collections/:id
  def destroy
    DeleteCollection.call(
      engine_client(@collection.version),
      @collection
    )

    redirect_to collections_path
  end

  # Soft-deletes the myc so that it no longer appears in listings.
  #
  # PUT /collections/:id/discard
  def discard
    unless @collection.discarded?
      @collection.discarded_at = Time.zone.now
      @collection.save(touch: false)

      flash.notice = t("trash.discarded_flash")
      flash[:undo_params] = [ undiscard_collection_path(@collection), { method: :put } ]
    end

    redirect_to(collection_path(@collection))
  end

  # Removes the soft-deletes of the scenario.
  #
  # PUT /collections/:id/undiscard
  def undiscard
    unless @collection.kept?
      @collection.discarded_at = nil
      @collection.save(touch: false)

      flash.notice = t("trash.undiscarded_flash")
      flash[:undo_params] = [ discard_collection_path(@collection), { method: :put } ]
    end

    redirect_back(fallback_location: discarded_path)
  end

  private

  def user_collections
    current_user
      .collections
      .kept
      .order(created_at: :desc)
  end

  def ensure_valid_config
    return if Settings.collections.uri

    redirect_to root_path,
      notice: "Missing collections.uri setting in config.yml"
  end

  def update_collection_params
    params.require(:collection).permit(:title, saved_scenario_ids: [])
  end

  def create_collection_params
    params.require(:collection).permit(:title, :version, saved_scenario_ids: [])
  end

  def create_transition_params
    params.require(:collection).permit(:version, :saved_scenario_ids)
  end

  def filter_params
    params.permit(:title)
  end

  def new_transition_collection
    current_user.collections.build(interpolation: true)
  end

  def elegible_scenarios
    current_user.saved_scenarios.available.where(end_year: 2050).order(updated_at: :desc)
  end

  def collection_title
    title = create_collection_params[:title]
    title.empty? ? t("collections.no_title") : title
  end
end
