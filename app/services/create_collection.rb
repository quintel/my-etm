class CreateCollection
  include Service

  def self.call(user, params)
    new(user, params).call
  end

  def initialize(user, params)
    @user = user
    @params = params
  end

  def call
    collection = @user.collections.build(
      title: collection_title,
      version: @params[:version],
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
    @params[:title].presence || I18n.t('collections.no_title')
  end

  def scenario_ids
    @params[:saved_scenario_ids].uniq.reject(&:blank?)
  end
end
