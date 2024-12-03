# frozen_string_literal: true

FactoryBot.define do
  factory :collection do
    user
    area_code { 'nl' }
    title { 'My Collection' }
    end_year { 2050 }

    transient do
      scenarios_count { 2 }
    end

    after(:create) do |myc, evaluator|
      create_list(
        :collection_scenario,
        evaluator.scenarios_count,
        collection: myc
      )
    end
  end

  factory :collection_scenario do
    collection
    sequence(:scenario_id) { |n| n }
  end
end
