# frozen_string_literal: true

FactoryBot.define do
  factory :version do
    sequence(:tag) { |n| "version.#{n}" }
    sequence(:url_prefix) { |n| "version-#{n}" }
  end
end
