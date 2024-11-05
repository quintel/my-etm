module Admin
  module AdminController
    extend ActiveSupport::Concern

    included do
      before_action :ensure_admin
    end

    private

    def ensure_admin
      render_not_found unless current_user&.admin?
    end
  end
end
