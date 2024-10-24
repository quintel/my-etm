class SavedScenariosController < ApplicationController
  load_resource only: %i[discard undiscard publish unpublish]
  load_and_authorize_resource only: %i[show new create edit update destroy]
  # before_action :set_saved_scenario, only: %i[ show edit update destroy publish unpublish]

  before_action only: %i[load] do
    authorize!(:read, @saved_scenario)
  end

  before_action only: %i[publish unpublish] do
    authorize!(:update, @saved_scenario)
  end

  before_action only: %i[discard undiscard] do
    authorize!(:destroy, @saved_scenario)
  end

  # GET /saved_scenarios or /saved_scenarios.json
  def index
    @saved_scenarios = SavedScenario.all
  end

  # GET /saved_scenarios/1 or /saved_scenarios/1.json
  def show
  end

  # GET /saved_scenarios/new
  def new
    @saved_scenario = SavedScenario.new
  end

  # GET /saved_scenarios/1/edit
  def edit
  end

  # POST /saved_scenarios or /saved_scenarios.json
  def create
    @saved_scenario = SavedScenario.new(saved_scenario_params)

    respond_to do |format|
      if @saved_scenario.save
        format.html {
 redirect_to @saved_scenario, notice: t("scenario.succesful_update") }
        format.json { render :show, status: :created, location: @saved_scenario }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @saved_scenario.errors, status: :unprocessable_entity }
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

  # DELETE /saved_scenarios/1 or /saved_scenarios/1.json
  def destroy
    @saved_scenario.destroy!

    respond_to do |format|
      format.html do
        redirect_to(
            saved_scenarios_path,
            status: :see_other,
            notice: "Saved scenario was successfully destroyed."
        )
      end
      format.json { head :no_content }
    end
  end

  # Makes a scenario public.
  def publish
    @saved_scenario.update(private: false)

    # ApiScenario::UpdatePrivacy.call_with_ids(
    #   engine_client,
    #   @saved_scenario.all_scenario_ids,
    #   private: false
    # )

    redirect_to saved_scenario_path(@saved_scenario)
  end

  # Makes a scenario private.
  def unpublish
    @saved_scenario.update(private: true)

    # ApiScenario::UpdatePrivacy.call_with_ids(
    #   engine_client,
    #   @saved_scenario.all_scenario_ids,
    #   private: true
    # )

    redirect_to saved_scenario_path(@saved_scenario)
  end

  # Soft-deletes the scenario so that it no longer appears in listings.
  #
  # PUT /saved_scenarios/:id/discard
  def discard
    unless @saved_scenario.discarded?
      @saved_scenario.discarded_at = Time.zone.now
      @saved_scenario.save(touch: false)

      flash.notice = t('scenario.trash.discarded_flash')
      flash[:undo_params] = [undiscard_saved_scenario_path(@saved_scenario), { method: :put }]
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

      flash.notice = t('scenario.trash.undiscarded_flash')
      flash[:undo_params] = [discard_saved_scenario_path(@saved_scenario), { method: :put }]
    end

    redirect_back(fallback_location: discarded_saved_scenarios_path)
  end

  private
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
end
