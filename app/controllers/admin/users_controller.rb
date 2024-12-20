module Admin
  class UsersController < ApplicationController
    include AdminController

    before_action :set_user, only: %i[confirm update edit]

    # All admins of the organisation
    def org
      @admins = User.where(admin: true).includes(:saved_scenarios)
    end

    # All users
    def all
      @users = User.all.includes(:saved_scenarios) # , :collections)
    end

    # Instant confirmation for our users that struggle with their spam
    def confirm
      @user.confirm
    end

    def edit; end

    def update
      if @user.update(user_params.compact_blank)
        flash[:notice] = t("admin.users.edit.success")

        respond_to do |format|
          format.html { redirect_to(admin_users_path) }

          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.update(:modal, ""),
              turbo_user,
              turbo_notice
            ]
          end
        end
      else
        render(:edit, status: :unprocessable_entity)
      end
    end

    private

    def set_user
      @user ||= User.find(params[:user_id])
    end

    def user_params
      attributes = [:name, :email, :password]
      attributes << :admin if current_user&.admin?
      params.require(:user).permit(*attributes)
    end

    def turbo_notice(message = nil)
      message ||= flash.delete(:notice)
      return if message.nil?

      turbo_stream.update(
        "toast",
        ToastComponent.new(type: :notice, message:).render_in(view_context)
      )
    end

    def turbo_user
      turbo_stream.replace(
        "user_#{@user.id}",
        Admin::UserRow::Component.new(
          user: @user,
          path: admin_edit_user_path(@user),
          confirm_path: admin_confirm_user_path(@user),
          confirmed: @user.confirmed?
        )
      )
    end
  end
end
