# frozen_string_literal: true

FactoryBot.define do
  factory :collection_saved_scenario do
    transient do
      user { nil }
    end
    
    saved_scenario { create(:saved_scenario, user: user) }
    collection
  end
end
