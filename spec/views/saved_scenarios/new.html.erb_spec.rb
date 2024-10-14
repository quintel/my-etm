require 'rails_helper'

RSpec.describe "saved_scenarios/new", type: :view do
  before(:each) do
    assign(:saved_scenario, SavedScenario.new(
      scenario_id: 1,
      scenario_id_history: "MyText",
      title: "MyString",
      description: "MyText",
      area_code: "MyString",
      end_year: 1,
      private: false
    ))
  end

  it "renders new saved_scenario form" do
    render

    assert_select "form[action=?][method=?]", saved_scenarios_path, "post" do

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
