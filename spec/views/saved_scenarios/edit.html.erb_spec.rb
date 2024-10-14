require 'rails_helper'

RSpec.describe "saved_scenarios/edit", type: :view do
  let(:saved_scenario) {
    SavedScenario.create!(
      scenario_id: 1,
      scenario_id_history: "MyText",
      title: "MyString",
      description: "MyText",
      area_code: "MyString",
      end_year: 1,
      private: false
    )
  }

  before(:each) do
    assign(:saved_scenario, saved_scenario)
  end

  it "renders the edit saved_scenario form" do
    render

    assert_select "form[action=?][method=?]", saved_scenario_path(saved_scenario), "post" do

      assert_select "input[name=?]", "saved_scenario[scenario_id]"

      assert_select "textarea[name=?]", "saved_scenario[scenario_id_history]"

      assert_select "input[name=?]", "saved_scenario[title]"

      assert_select "textarea[name=?]", "saved_scenario[description]"

      assert_select "input[name=?]", "saved_scenario[area_code]"

      assert_select "input[name=?]", "saved_scenario[end_year]"

      assert_select "input[name=?]", "saved_scenario[private]"
    end
  end
end
