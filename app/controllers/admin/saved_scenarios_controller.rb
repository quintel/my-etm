module Admin
  class SavedScenariosController < ApplicationController
    include AdminController
    include Pagy::Method
    include Filterable

    # GET /admin/saved_scenarios
    def index
      @pagy_admin_saved_scenarios, @saved_scenarios = pagy(admin_saved_scenarios)
      @filtered_ids = admin_saved_scenarios.pluck(:id).join(",")
      @filters = {
        featured: true,
        area_codes: area_codes_for_filter,
        end_years: admin_saved_scenarios.group(:end_year).count,
        versions: admin_saved_scenarios.joins(:version).pluck("version.tag", "version.id").uniq
      }

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    # Renders a partial of saved_scenarios based on turbo search and filters
    #
    # GET admin/saved_scenarios/list
    def list
      filtered = filter!(SavedScenario)
        .available
        .includes(:featured_scenario, :users)

      @pagy_admin_saved_scenarios, @saved_scenarios = pagy(filtered)
      @filtered_ids = filtered.pluck(:id).join(",")

      respond_to do |format|
        format.html { render(
          partial: "saved_scenarios",
          locals: {
            saved_scenarios: @saved_scenarios,
            pagy_admin_saved_scenarios: @pagy_admin_saved_scenarios,
            filtered_ids: @filtered_ids
          }
        ) }
        format.turbo_stream { render(:index) }
      end
    end

    # POST admin/saved_scenarios/batch_dump
    #
    # Creates a dump of multiple saved scenarios as an ETM file (Zstandard-compressed JSON)
    def batch_dump
      result = SavedScenarioPacker::Dump.new(
        saved_scenario_ids,
        streaming_engine_client(Version.default),
        current_user
      ).call

      if result.success?
        dump = result.value!
        send_file(
          dump.file_path,
          filename: File.basename(dump.file_path),
          type: "application/x-etm",
          disposition: "attachment"
        )
      else
        flash[:alert] = result.failure
        redirect_to admin_saved_scenarios_path
      end
    end

    private

    def admin_saved_scenarios
      @admin_saved_scenarios ||= SavedScenario
        .available
        .includes(:featured_scenario, :users)
        .order(updated_at: :desc)
    end

    # Make sure to group all dup area_codes for nl together
    def area_codes_for_filter
      area_codes = admin_saved_scenarios.group(:area_code).count

      dups = area_codes.select { |k, _v| SavedScenario::AREA_DUPS.include?(k) }

      if dups.size > 1
        area_codes = area_codes.except(*dups.keys)
        area_codes[dups.keys.first] = dups.sum { |_k, v| v }
      end

      area_codes = area_codes.sort_by { |_k, v| v }.reverse
    end

    def saved_scenario_ids
      params.require(:saved_scenario_ids).split(",").map(&:to_i)
    end
  end
end
