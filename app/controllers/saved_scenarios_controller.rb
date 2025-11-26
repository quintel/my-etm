class SavedScenariosController < ApplicationController
  include Pagy::Method
  include Filterable

  load_resource only: %i[discard undiscard publish unpublish confirm_destroy]
  load_and_authorize_resource only: %i[show new create edit update destroy]

  before_action :require_user, only: %i[index]
  before_action :welcome_back

  before_action only: %i[publish unpublish] do
    authorize!(:update, @saved_scenario)
  end

  before_action only: %i[discard undiscard confirm_destroy] do
    authorize!(:destroy, @saved_scenario)
  end

  # GET /saved_scenarios
  def index
    @pagy_saved_scenarios, @saved_scenarios = pagy(ordered_user_saved_scenarios)
    @area_codes = area_codes_for_filter
    @end_years = @saved_scenarios.pluck(:end_year).tally
    @versions = @saved_scenarios.map(&:version).uniq

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  # Renders a partial of saved_scenarios based on turbo search and filters
  #
  # GET /saved_scenarios/list
  def list
    filtered = filter!(SavedScenario)
      .viewable_by?(current_user)
      .available
      .includes(:featured_scenario, :users)
      .order("updated_at DESC")

    @pagy_saved_scenarios, @saved_scenarios = pagy(filtered)

    respond_to do |format|
      format.html { render(
        partial: "saved_scenarios",
        locals: { saved_scenarios: @saved_scenarios, pagy_saved_scenarios: @pagy_saved_scenarios }
      ) }
      format.turbo_stream { render(:index) }
    end
  end

  # GET /saved_scenarios/1
  def show
  end

  # GET /saved_scenarios/new
  def new
    @saved_scenario = SavedScenario.new
  end

  # GET /saved_scenarios/1/edit
  def edit
  end

  # POST /saved_scenarios
  def create
    ActiveRecord::Base.transaction do
      @saved_scenario = SavedScenario.new(saved_scenario_params)

      if @saved_scenario.save
        SavedScenarioUser.create!(
          saved_scenario: @saved_scenario,
          user: current_user,
          role_id: User::Roles.index_of(:scenario_owner)
        )

        respond_to do |format|
          format.html {
            redirect_to @saved_scenario, notice: t("scenario.succesful_update") }
        end
      else
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
        end
        # Rollback the transaction if the scenario save fails
        raise ActiveRecord::Rollback
      end
    end
  end

  # PATCH/PUT /saved_scenarios/1 or /saved_scenarios/1.json
  def update
    respond_to do |format|
      if @saved_scenario.update(saved_scenario_update_params)
        format.html {
 redirect_to @saved_scenario, notice: t("scenario.succesful_update") }
        format.json { render :show, status: :ok, location: @saved_scenario }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @saved_scenario.errors, status: :unprocessable_entity }
      end
    end
  end

  def confirm_destroy
    render :confirm_destroy, layout: "application"
  end

  # DELETE /saved_scenarios/1 or /saved_scenarios/1.json
  def destroy
    @saved_scenario.destroy
    flash.notice = t("scenario.trash.deleted_flash")
    redirect_to discarded_index_path
  end

  # Makes a scenario public.
  def publish
    @saved_scenario.update(private: false)

    ApiScenario::UpdatePrivacy.call_with_ids(
      engine_client(@saved_scenario.version),
      @saved_scenario.all_scenario_ids,
      private: false
    )

    redirect_to saved_scenario_path(@saved_scenario)
  end

  # Makes a scenario private.
  def unpublish
    @saved_scenario.update(private: true)

    ApiScenario::UpdatePrivacy.call_with_ids(
      engine_client(@saved_scenario.version),
      @saved_scenario.all_scenario_ids,
      private: true
    )

    redirect_to saved_scenario_path(@saved_scenario)
  end

  # Soft-deletes the scenario so that it no longer appears in listings.
  #
  # PUT /saved_scenarios/:id/discard
  def discard
    unless @saved_scenario.discarded?
      @saved_scenario.discarded_at = Time.zone.now
      @saved_scenario.save(touch: false)

      flash.notice = t("trash.discarded_flash")
      flash[:undo_params] = undiscard_saved_scenario_path(@saved_scenario)
    end

    redirect_back(fallback_location: saved_scenarios_path)
  end

  # Removes the soft-deletes of the scenario.
  #
  # PUT /saved_scenarios/:id/undiscard
  def undiscard
    unless @saved_scenario.kept?
      @saved_scenario.discarded_at = nil
      @saved_scenario.save(touch: false)

      flash.notice = t("trash.undiscarded_flash")
      flash[:undo_params] = discard_saved_scenario_path(@saved_scenario)
    end

    redirect_back(fallback_location: discarded_path)
  end

  private

  def user_saved_scenarios
    current_user
      .saved_scenarios
      .available
      .includes(:featured_scenario, :users)
  end

  def ordered_user_saved_scenarios
    user_saved_scenarios.order("updated_at DESC")
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_saved_scenario
    @saved_scenario = SavedScenario.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def saved_scenario_params
    params.require(:saved_scenario).permit(
      :scenario_id, :scenario_id_history, :title,
      :description, :area_code, :end_year, :private,
      :created_at, :updated_at, :discarded_at
    )
  end

  # Only allow a list of trusted parameters through.
  def saved_scenario_update_params
    params.require(:saved_scenario).permit(
      :title, :description
    )
  end

  # Make sure to group all dup area_codes for nl together
  def area_codes_for_filter
    area_codes = user_saved_scenarios.group(:area_code).count

    dups = area_codes.select { |k, _v| SavedScenario::AREA_DUPS.include?(k) }

    if dups.size > 1
      area_codes = area_codes.except(*dups.keys)
      area_codes[dups.keys.first] = dups.sum { |_k, v| v }
    end

    area_codes = area_codes.sort_by { |_k, v| v }.reverse
  end
end
