# frozen_string_literal: true

# Allows featuring and unfeaturing saved scenarios.
class FeaturedScenariosController < ApplicationController
  before_action :ensure_admin
  before_action :remember_page, only: :show
  before_action :set_featured_scenario, only: %i[show update confirm_destroy destroy]

  def create
    # TODO: Should take owner id instead of owner!
    @featured_scenario = FeaturedScenario.new(
      featured_scenario_params.merge(
        { saved_scenario: saved_scenario, owner: owner }
      )
    )

    if @featured_scenario.save
      redirect_to saved_scenario_url(saved_scenario)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def show
    render :edit
  end

  def update
    if @featured_scenario.update(featured_scenario_params)
      redirect_to saved_scenario_url(saved_scenario)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def confirm_destroy
    render :confirm_destroy, layout: "application"
  end

  def destroy
    @featured_scenario.destroy
    redirect_to saved_scenario_url(saved_scenario)
  end

  private

  def featured_scenario_params
    params.require(:featured_scenario)
      .permit(
        :description_en, :description_nl, :group,
        :title_en, :title_nl, :owner_id
      )
  end

  def saved_scenario
    SavedScenario.find(params[:saved_scenario_id])
  end

  def owner
    if featured_scenario_params[:owner_id]
      FeaturedScenarioUser.find(featured_scenario_params[:owner_id])
    end
  end

  def set_featured_scenario
    @featured_scenario ||=
      saved_scenario.featured_scenario || FeaturedScenario.new(
        saved_scenario: saved_scenario,
        title_en: saved_scenario.title,
        title_nl: saved_scenario.title,
        description_en: saved_scenario.description,
        description_nl: saved_scenario.description
      )
  end

  def ensure_admin
    render_not_found unless current_user&.admin?
  end
end
