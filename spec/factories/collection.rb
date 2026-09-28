# frozen_string_literal: true

FactoryBot.define do
  factory :collection do
    user
    area_code { 'nl' }
    title { 'My Collection' }
    end_year { 2050 }
    version { Version.find_by(tag: "latest") }

    transient do
      scenarios_count { 2 }
      # Linked saved scenarios, which v2 requires at least one of on create. Off by default: a
      # member built here is public, and a collection whose members are all public is readable by
      # a signed-out caller, so defaulting it would change what unrelated specs test.
      saved_scenarios_count { 0 }
    end

    after(:create) do |myc, evaluator|
      create_list(
        :collection_scenario,
        evaluator.scenarios_count,
        collection: myc
      )

      evaluator.saved_scenarios_count.times do |index|
        create(
          :collection_saved_scenario,
          collection: myc,
          saved_scenario: create(:saved_scenario, user: myc.user, end_year: 2050 + index),
          saved_scenario_order: index + 1
        )
      end
    end
  end

  factory :collection_scenario do
    collection
    sequence(:scenario_id) { |n| n }
  end
end
