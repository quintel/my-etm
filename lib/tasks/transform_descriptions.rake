namespace :data do
  desc "Transform tmp_description into Action Text description"
  task transform_descriptions: :environment do
    SavedScenario.find_each do |scenario|
      next if scenario.tmp_description.blank?

      # Update directly without changing updated_at:
      scenario.update_columns(description: scenario.tmp_description)
    end
  end
end
