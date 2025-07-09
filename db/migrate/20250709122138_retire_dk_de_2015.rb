class RetireDkDe2015 < ActiveRecord::Migration[7.1]
  def up
    [SavedScenario, Collection].each do |model|
      model.where(area_code: 'de').update_all(area_code: 'DE_germany')
      model.where(area_code: 'dk').update_all(area_code: 'DK_denmark')
    end
  end
end
