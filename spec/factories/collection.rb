# frozen_string_literal: true

FactoryBot.define do
  factory :collection do
    user
    area_code { 'nl' }
    title { 'My Collection' }
    end_year { 2050 }
    version { Version.find_by(tag: "latest") }
    interpolation { false }

    transient do
      scenarios_count { 2 }
      saved_scenarios_count { interpolation ? 1 : 0 }
    end

    after(:build) do |collection, evaluator|
      evaluator.scenarios_count.times do
        collection.scenarios << build(
          :collection_scenario,
          collection: collection
        )
      end

      evaluator.saved_scenarios_count.times do
        collection.collection_saved_scenarios << build(
          :collection_saved_scenario,
          collection: collection,
          user: collection.user
        )
      end
    end
  end

  factory :collection_scenario do
    collection
    sequence(:scenario_id) { |n| n }
  end
end
