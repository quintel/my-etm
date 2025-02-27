class DiscardedController < ApplicationController
  include Pagy::Backend
  before_action :require_user
  before_action :remember_page

  def index
    discarded_resources = (
      current_user
        .saved_scenarios
        .discarded
        .includes(:featured_scenario, :users).to_a +
      current_user
        .collections
        .discarded.to_a
    ).sort_by(&:updated_at).reverse

    @pagy, @resources = pagy_array(discarded_resources, items: 10)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
end
