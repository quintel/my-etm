class CreateCollection
  Result = Struct.new(:successful?, :collection, :errors)

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
      Result.new(true, collection, nil)
    else
      Result.new(false, nil, collection.errors.full_messages)
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
