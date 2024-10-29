# frozen_string_literal: true

FactoryBot.define do
  factory :featured_scenario do
    saved_scenario
    group { FeaturedScenario::GROUPS.first }
    title_en { 'English title' }
    title_nl { 'Dutch title' }

    owner { association :featured_scenario_user }
  end
end
