require 'rails_helper'

RSpec.describe "saved_scenarios/index", type: :view do
  before(:each) do
    assign(:saved_scenarios, [
      SavedScenario.create!(
        scenario_id: 2,
        scenario_id_history: [],
        title: "Title",
        description: "MyText",
        area_code: "Area Code",
        end_year: 3,
        private: false
      ),
      SavedScenario.create!(
        scenario_id: 2,
        scenario_id_history: [],
        title: "Title",
        description: "MyText",
        area_code: "Area Code",
        end_year: 3,
        private: false
      )
    ])
  end

  # it "renders a list of saved_scenarios" do
  #   render
  #   cell_selector = 'div>p'
  #   assert_select cell_selector, text: Regexp.new(2.to_s), count: 2
  #   assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
  #   assert_select cell_selector, text: Regexp.new("Title".to_s), count: 2
  #   assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
  #   assert_select cell_selector, text: Regexp.new("Area Code".to_s), count: 2
  #   assert_select cell_selector, text: Regexp.new(3.to_s), count: 2
  #   assert_select cell_selector, text: Regexp.new(false.to_s), count: 2
  # end
end
