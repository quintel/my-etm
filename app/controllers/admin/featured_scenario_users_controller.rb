
module Admin
  class FeaturedScenarioUsersController < ApplicationController
    before_action :set_featured_scenario_user, only: [:update, :edit]

    def index
      @featured_scenario_users = FeaturedScenarioUser.all
    end

    def edit;end

    def new
      @featured_scenario_user = FeaturedScenarioUser.new
    end

    def create
      @featured_scenario_user = FeaturedScenarioUser.new(featured_scenario_user_params)

      if @featured_scenario_user.save
        flash[:notice] = t("admin.users.edit.success")

        respond_to do |format|
          format.html { redirect_to(admin_featured_scenario_users_path) }

          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.update(:modal, ""),
              turbo_new_user,
              turbo_notice
            ]
          end
        end
      else
        render :new
      end
    end

    def update
      if @featured_scenario_user.update(featured_scenario_user_params.compact_blank)
        flash[:notice] = t("admin.users.edit.success")

        respond_to do |format|
          format.html { redirect_to(admin_featured_scenario_users_path) }

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

    def set_featured_scenario_user
      @featured_scenario_user ||= FeaturedScenarioUser.find(params[:id])
    end

    def featured_scenario_user_params
      params.require(:featured_scenario_user).permit(:name, :user_id)
    end

    def turbo_user
      turbo_stream.replace(
        "user_#{@featured_scenario_user.id}",
        Admin::FeaturedUserRow::Component.new(
          user: @featured_scenario_user,
          path: edit_admin_featured_scenario_user_path(@featured_scenario_user),
        )
      )
    end

    def turbo_new_user
      turbo_stream.append(
        "featured_users",
        Admin::FeaturedUserRow::Component.new(
          user: @featured_scenario_user,
          path: edit_admin_featured_scenario_user_path(@featured_scenario_user),
        )
      )
    end
  end
end
