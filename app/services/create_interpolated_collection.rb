# frozen_string_literal: true

# Receives a 2050 Engine::Scenario and creates scenarios for selected years, with
# input values interpolated from the source scenario.
#
# Each interpolated scenario is saved as a SavedScenario owned by the user, so that it appears
# alongside their other scenarios. The source scenario is linked as it is.
class CreateInterpolatedCollection
  include Service

  DEFAULT_YEARS = [2030, 2040].freeze

  # Public: Creates a new collection and interpolated scenarios.
  #
  # http_client    - The client used to communiate with ETEngine.
  # saved_scenario - The SavedScenario to be used as the base scenario for interpolating one or more
  #                  new scenarios.
  # user           - The user to which the resulting Collection should belong.
  # years          - An optional array of years for which interpolated scenarios
  #                  will be created.
  #
  def initialize(http_client, saved_scenario, user, years = DEFAULT_YEARS)
    @http_client = http_client
    @saved_scenario = saved_scenario
    @user = user
    @years = (years).uniq
  end

  # Internal: Creats interpolated scenarios for the chosen years, and the
  # Collection records.
  #
  # Returns a ServiceResult.
  def call
    if interpolations.values.all?(&:successful?)
      ServiceResult.success(create_collection)
    else
      # Any responses which did succeed, should have their protected status
      # removed, since there's no need to keep the scenario.
      clean_up_failure

      # The last response will always be the one with the errors, as we give up
      # on the first failure.
      ServiceResult.failure(interpolations.values.last.errors)
    end
  rescue ActiveRecord::RecordInvalid => e
    clean_up_failure

    # The user does not provide any data which should cause saving the collection to
    # fail. Re-raise the exception so we can log it.
    raise e
  end

  private

  def create_collection
    collection = Collection.new_from_saved_scenario(@saved_scenario, user: @user)
    collection.version ||= @saved_scenario.version || Version.default

    interpolated = interpolations.map do |end_year, sresult|
      build_interpolated_scenario(collection, end_year, sresult.value["id"])
    end

    Collection.transaction do
      interpolated.each do |saved_scenario|
        # Saved and owned first: a collection may only link a scenario its owner can read.
        saved_scenario.save!
        saved_scenario.user = @user
      end

      # Numbered so that the transition path runs from its earliest end year to its latest. The
      # Collections app shows the scenarios in this order.
      ([ @saved_scenario ] + interpolated).sort_by(&:end_year).each.with_index(1) do |scenario, order|
        collection.collection_saved_scenarios.build(
          saved_scenario: scenario,
          saved_scenario_order: order
        )
      end

      collection.save!
    end

    interpolated.each { |saved_scenario| enqueue_engine_callbacks(saved_scenario) }

    collection
  end

  # Internal: An interpolated scenario, kept as a SavedScenario so that it appears in the user's
  # own scenario list. It takes its area, version and privacy from the source scenario.
  #
  # Returns an unsaved SavedScenario.
  def build_interpolated_scenario(collection, end_year, scenario_id)
    SavedScenario.new(
      scenario_id:,
      end_year:,
      title: collection.interpolated_scenario_title(end_year),
      area_code: @saved_scenario.area_code,
      version: @saved_scenario.version,
      private: @saved_scenario.private
    )
  end

  # Internal: Asks ETEngine to protect the scenario, set its roles and tag its version, as happens
  # for any other saved scenario.
  def enqueue_engine_callbacks(saved_scenario)
    SavedScenarioCallbacksJob.perform_later(
      saved_scenario.scenario_id,
      @user.id,
      saved_scenario.version.tag,
      [ :protect, :set_roles, :tag_version ],
      saved_scenario_id: saved_scenario.id
    )
  end

  # Internal: Sends requests to ETEngine to create the interpolated scenarios.
  #
  # As requests are sent synchronously, this stops as soon as any one request
  # fails.
  #
  # Returns a Hash of end year to ServiceResult.
  def interpolations
    @interpolations ||= begin
      any_errors = false

      @years.each_with_object({}) do |year, results|
        next if any_errors

        res = ApiScenario::Interpolate.call(
          @http_client,
          @saved_scenario.scenario_id,
          year,
          keep_compatible: true
        )

        any_errors = res.failure?

        results[year] = res
      end
    end
  end

  def clean_up_failure
    interpolations.each_value do |sresult|
      next unless sresult.successful?

      ApiScenario::SetCompatibility.dont_keep_compatible(@http_client, sresult.value['id'])
    end
  end
end
