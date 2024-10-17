require 'rails_helper'

RSpec.describe "saved_scenarios/show", type: :view do
  before(:each) do
    assign(:saved_scenario, SavedScenario.create!(
      scenario_id: 2,
      scenario_id_history: [ 1, 3 ],
      title: "Title",
      description: "MyText",
      area_code: "Area Code",
      end_year: 3,
      private: false
    ))
  end

  # it "renders attributes in <p>" do
  #   render
  #   expect(rendered).to match(/2/)
  #   expect(rendered).to match(/MyText/)
  #   expect(rendered).to match(/Title/)
  #   expect(rendered).to match(/MyText/)
  #   expect(rendered).to match(/Area Code/)
  #   expect(rendered).to match(/3/)
  #   expect(rendered).to match(/false/)
  # end
end
