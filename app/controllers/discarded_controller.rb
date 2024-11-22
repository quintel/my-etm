# Index of all discarded scenarios and collections
class DiscardedController < ApplicationController
  before_action :require_user

  def index
    @resources = (
      current_user
        .saved_scenarios
        .discarded
        .includes(:featured_scenario, :users) +
      current_user
        .collections
        .discarded
    ).sort_by(&:updated_at)
  end
end
