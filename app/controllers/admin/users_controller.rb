module Admin
  class UsersController < ApplicationController
    include AdminController
    include Pagy::Backend
    include Filterable

    before_action :set_user, only: %i[confirm update edit]

    # All admins of the organisation
    def org
      @admins = User.where(admin: true).includes(:saved_scenarios)
    end

    # All users
    def index
      @pagy_admin_users, @users = pagy_countless(admin_all_users)

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    # Renders a partial of users based on turbo search and filters
    #
    # GET /users/list
    def list
      filtered = filter!(User)

      @pagy_admin_users, @users = pagy(filtered)

      respond_to do |format|
        format.html { render(
          partial: "users",
          locals: {
            users: @users,
            pagy_admin_users: @pagy_admin_users
          }
        ) }
        format.turbo_stream { render(:index) }
      end
    end

    # Instant confirmation for our users that struggle with their spam
    def confirm
      @user.confirm

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.remove("confirm_button_#{@user.id}")
        end
        format.html { redirect_to request.referer, notice: "User confirmed!" }
      end
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

    def admin_all_users
      User.all.includes(:saved_scenarios)
    end
  end
end
