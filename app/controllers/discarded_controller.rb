# Index of all discarded scenarios and collections
class DiscardedController < ApplicationController
  before_action :require_user

  def index
    @resources = current_user
      .saved_scenarios
      .discarded
      .includes(:featured_scenario, :users)
      .order('updated_at DESC')
  end
end
