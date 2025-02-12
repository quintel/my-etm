# frozen_string_literal: true

class UpdateCollection
  extend Dry::Initializer
  include Service

  param :collection
  param :user
  param :settings

  def call
    validation_result = validate_settings(settings)

    unless validation_result.success?
      return ServiceResult.failure(validation_result.errors.to_h.values.flatten)
    end

    validated_settings = validation_result.to_h

    scenario_ids = validated_settings.delete(:scenario_ids)
    saved_scenario_ids = validated_settings.delete(:saved_scenario_ids)

    collection.attributes = validated_settings

    Collection.transaction do
      update_scenarios(collection, scenario_ids.uniq) if scenario_ids&.any?
      update_saved_scenarios(collection, saved_scenario_ids.uniq) if saved_scenario_ids&.any?
      collection.save!
    rescue ActiveRecord::RecordInvalid
      return ServiceResult.failure(collection.errors.full_messages)
    end

    ServiceResult.success(collection.reload)
  end

  private

  def validate_settings(settings)
    schema = Dry::Schema.Params do
      optional(:title).filled(:string)
      optional(:area_code).filled(:string)
      optional(:end_year).filled(:integer)
      optional(:scenario_ids).array(:integer, min_size?: 1, max_size?: 100) { gt?(0) }
      optional(:saved_scenario_ids).array(:integer, min_size?: 1, max_size?: 100) { gt?(0) }
    end

    schema.call(settings)
  end

  def update_scenarios(collection, scenario_ids)
    existing_ids = collection.scenarios.pluck(:scenario_id)
    new_ids      = scenario_ids - existing_ids
    delete_ids   = existing_ids - scenario_ids

    collection.scenarios.delete_by(scenario_id: delete_ids)
    new_ids.each { |id| collection.scenarios.create!(scenario_id: id) }
  end

  def update_saved_scenarios(collection, saved_scenario_ids)
    existing_ids = collection.collection_saved_scenarios.pluck(:saved_scenario_id)
    new_ids      = saved_scenario_ids - existing_ids
    delete_ids   = existing_ids - saved_scenario_ids

    collection.collection_saved_scenarios.where(saved_scenario_id: delete_ids).delete_all
    new_ids.each { |id| collection.collection_saved_scenarios.create!(saved_scenario_id: id) }
  end
end
