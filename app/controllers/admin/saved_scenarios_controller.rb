module Admin
  class SavedScenariosController < ApplicationController
    include AdminController
    include Pagy::Backend

    # GET /admin/saved_scenarios
    def index
      @pagy_admin_saved_scenarios, @saved_scenarios = pagy_countless(admin_saved_scenarios)

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    # TODO: Implement other methods
    #   # GET /saved_scenarios/1
    # def show
    # end

    # # Renders a partial of saved_scenarios based on turbo search and filters
    # #
    # # GET /saved_scenarios/list
    # def list
    #   filtered = filter!(SavedScenario)
    #     .available
    #     .includes(:featured_scenario, :users)

    #   @pagy_admin_saved_scenarios, @saved_scenarios = pagy(filtered)

    #   respond_to do |format|
    #     format.html { render(
    #       partial: "saved_scenarios",
    #       locals: { saved_scenarios: @saved_scenarios, pagy_admin_saved_scenarios: @pagy_admin_saved_scenarios }
    #     ) }
    #     format.turbo_stream { render(:index) }
    #   end
    # end

    # def paginate
    #   index
    # end


    private

    def admin_saved_scenarios
      SavedScenario.available
      .includes(:featured_scenario, :users)
      .order(updated_at: :desc)
    end
  end
end
