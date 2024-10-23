require 'rails_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to test the controller code that
# was generated by Rails when you ran the scaffold generator.
#
# It assumes that the implementation code is generated by the rails scaffold
# generator. If you are using any extension libraries to generate different
# controller code, this generated spec may or may not pass.
#
# It only uses APIs available in rails and/or rspec-rails. There are a number
# of tools you can use to make these specs even more expressive, but we're
# sticking to rails and rspec-rails APIs to keep things simple and stable.

RSpec.describe "/saved_scenarios", type: :request do
  # This should return the minimal set of attributes required to create a valid
  # SavedScenario. As you add validations to SavedScenario, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) {
    {
      title: 'Baking a scenario',
      scenario_id: 1234,
      end_year: 2050,
      area_code: 'nl2019'
    }
  }

  let(:invalid_attributes) {
    {
      title: 'Baking a scenario',
      scenario_id: 'hello'
    }
  }

  let!(:user_scenario) { FactoryBot.create(:saved_scenario, id: 648695) }

  pending "GET /index" do
    it "renders a successful response" do
      FactoryBot.create(:saved_scenario)
      get saved_scenarios_url
      expect(response).to be_successful
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      saved_scenario = FactoryBot.create(:saved_scenario, valid_attributes)
      get saved_scenario_url(saved_scenario)
      expect(response).to be_successful
    end
  end

  # describe "GET /new" do
  #   it "renders a successful response" do
  #     get new_saved_scenario_url
  #     expect(response).to be_successful
  #   end
  # end

  describe "GET /edit" do
    it "renders a successful response" do
      saved_scenario = FactoryBot.create(:saved_scenario, valid_attributes)
      get edit_saved_scenario_url(saved_scenario)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new SavedScenario" do
        expect {
          post(saved_scenarios_url, params: { saved_scenario: valid_attributes })
        }.to change(SavedScenario, :count).by(1)
      end

      it "redirects to the created saved_scenario" do
        post saved_scenarios_url, params: { saved_scenario: valid_attributes }
        expect(response).to redirect_to(saved_scenario_url(SavedScenario.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new SavedScenario" do
        expect {
          post(saved_scenarios_url, params: { saved_scenario: invalid_attributes })
        }.to change(SavedScenario, :count).by(0)
      end

      it "renders a response with 422 status (i.e. to display the 'new' template)" do
        post saved_scenarios_url, params: { saved_scenario: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) {
        skip("Add a hash of attributes valid for your model")
      }

      it "updates the requested saved_scenario" do
        saved_scenario = FactoryBot.create(:saved_scenario, valid_attributes)
        patch saved_scenario_url(saved_scenario), params: { saved_scenario: new_attributes }
        saved_scenario.reload
        skip("Add assertions for updated state")
      end

      it "redirects to the saved_scenario" do
        saved_scenario = FactoryBot.create(:saved_scenario, valid_attributes)
        patch saved_scenario_url(saved_scenario), params: { saved_scenario: new_attributes }
        saved_scenario.reload
        expect(response).to redirect_to(saved_scenario_url(saved_scenario))
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status (i.e. to display the 'edit' template)" do
        saved_scenario = FactoryBot.create(:saved_scenario, valid_attributes)
        patch saved_scenario_url(saved_scenario), params: { saved_scenario: invalid_attributes }
        expect(response).to have_http_status(:found)
      end
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested saved_scenario" do
      saved_scenario = FactoryBot.create(:saved_scenario, valid_attributes)
      expect {
        delete(saved_scenario_url(saved_scenario))
      }.to change(SavedScenario, :count).by(-1)
    end

    it "redirects to the saved_scenarios list" do
      saved_scenario = FactoryBot.create(:saved_scenario, valid_attributes)
      delete saved_scenario_url(saved_scenario)
      expect(response).to redirect_to(saved_scenarios_url)
    end
  end

  describe 'PUT /publish' do
    before do
      # sign_in(user)
      # session[:setting] = Setting.new
      allow(ApiScenario::UpdatePrivacy).to receive(:call_with_ids)
    end

    context 'with an owned saved scenario' do
      before do
        user_scenario.update!(private: true)
        put publish_saved_scenario_url(user_scenario)
      end

      it 'redirects to the scenario' do
        expect(response).to be_redirect
      end

      it 'makes the scenario public' do
        expect(user_scenario.reload).not_to be_private
      end

      pending 'updates the API scenarios' do
        expect(ApiScenario::UpdatePrivacy).to have_received(:call_with_ids).with(
          anything, [user_scenario.id], private: false
        )
      end
    end

    pending 'with an unowned saved scenario' do
      before do
        admin_scenario.update!(private: true)
        post(:publish, params: { id: admin_scenario.id })
      end

      it 'returns 404' do
        expect(response).to be_not_found
      end

      it 'does not change the scenario privacy' do
        expect(admin_scenario.reload).to be_private
      end

      it 'does not update the API scenarios' do
        expect(ApiScenario::UpdatePrivacy).not_to have_received(:call_with_ids)
      end
    end
  end

  describe 'PUT /unpublish' do
    before do
      # sign_in(user)
      allow(ApiScenario::UpdatePrivacy).to receive(:call_with_ids)
      # session[:setting] = Setting.new
    end

    context 'with an owned saved scenario' do
      before do
        user_scenario.update!(private: false)
        put unpublish_saved_scenario_url(user_scenario)
      end

      it 'redirects to the scenario listing' do
        expect(response).to be_redirect
      end

      it 'makes the scenario public' do
        expect(user_scenario.reload).to be_private
      end

      pending 'updates the API scenarios' do
        expect(ApiScenario::UpdatePrivacy).to have_received(:call_with_ids).with(
          anything, [user_scenario.id], private: true
        )
      end
    end

    pending 'with an unowned saved scenario' do
      before do
        user_scenario.update!(private: false)
        post(:unpublish, params: { id: admin_scenario.id })
      end

      it 'returns 404' do
        expect(response).to be_not_found
      end

      it 'does not change the scenario privacy' do
        expect(admin_scenario.reload).not_to be_private
      end

      it 'does not update the API scenarios' do
        expect(ApiScenario::UpdatePrivacy).not_to have_received(:call_with_ids)
      end
    end
  end
end
