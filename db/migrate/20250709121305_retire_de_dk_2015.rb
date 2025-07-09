class RetireDeDk2015 < ActiveRecord::Migration[7.1]
  def up
    SavedScenario.where(area_code: ['de', 'dk']).find_each do |scenario|
      case scenario.area_code
      when 'de'
        scenario.update!(area_code: 'DE_germany')
      when 'dk'
        scenario.update!(area_code: 'DK_denmark')
      end
    end
  end
end
