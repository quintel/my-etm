class CreateCollection
  extend Dry::Initializer
  include Service

  param :user
  param :settings

  def call
    collection = user.collections.build(
      title: collection_title,
      version: settings[:version],
      interpolation: false
    )

    scenario_ids.each do |saved_scenario_id|
      collection.collection_saved_scenarios.build(saved_scenario_id: saved_scenario_id)
    end

    if collection.save
      ServiceResult.success(collection)
    else
      ServiceResult.failure(collection.errors.full_messages)
    end
  end

  private

  def collection_title
    settings[:title].presence || I18n.t('collections.no_title')
  end

  def scenario_ids
    settings[:saved_scenario_ids].uniq.reject(&:blank?)
  end
end
