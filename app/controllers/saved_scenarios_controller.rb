class SavedScenariosController < ApplicationController
  before_action :set_saved_scenario, only: %i[ show edit update destroy ]

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
 redirect_to @saved_scenario, notice: "Saved scenario was successfully created." }
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
      if @saved_scenario.update(saved_scenario_params)
        format.html {
 redirect_to @saved_scenario, notice: "Saved scenario was successfully updated." }
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
      format.html {
 redirect_to saved_scenarios_path, status: :see_other,
   notice: "Saved scenario was successfully destroyed." }
      format.json { head :no_content }
    end
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
end
