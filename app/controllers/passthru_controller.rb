class PassthruController < ApplicationController
  def last
    redirect_to cookies[:etm_last_visited_page] || root_path
  end
end