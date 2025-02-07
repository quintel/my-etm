
module Admin
  class FeaturedScenarioUsersController < ApplicationController

    def new
      @featured_scenario_user = FeaturedScenarioUser.new
    end

    def create
      @featured_scenario_user = FeaturedScenarioUser.new(featured_scenario_user_params)

      if @featured_scenario_user.save
        redirect_to admin_featured_scenario_users_path, notice: "Featured Scenario User created!"
      else
        render :new
      end
    end

    private

    def featured_scenario_user_params
      params.require(:featured_scenario_user).permit(:name, :user_id)
    end
  end
end
