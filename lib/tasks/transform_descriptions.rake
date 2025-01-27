namespace :data do
  desc "Transform tmp_description into Action Text description"
  task transform_descriptions: :environment do
    SavedScenario.find_each do |scenario|
      next if scenario.tmp_description.blank?

      # Assign Action Text description:
      scenario.description = scenario.tmp_description
      scenario.save!
    end
  end
end
