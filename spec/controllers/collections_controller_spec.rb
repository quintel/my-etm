# frozen_string_literal: true

require 'rails_helper'

# Required for class_double
require_relative '../../app/services/create_interpolated_collection'

describe CollectionsController do
  let(:client) { Faraday.new(url: 'http://et.engine') }

  before { allow(MyEtm::Auth).to receive(:engine_client).and_return(client) }

  describe '#create_transition' do
    context 'when signed in and given a valid saved scenario ID' do
      let(:scenario) { create(:saved_scenario, end_year: 2050, user: user) }
      let(:user) { create(:user) }
      let(:collection) { create(:collection, scenarios_count: 1) }

      let!(:service) { class_double('CreateInterpolatedCollection').as_stubbed_const }

      before do
        sign_in user

        allow(service).to receive(:call).and_return(ServiceResult.success(collection))
      end

      it 'redirects to the collection' do
        post :create_transition, params: { collection: { saved_scenario_ids: scenario.id, version: Version.tags.last } }

        expect(response).to redirect_to(
          collection_path(Collection.last)
        )
      end

      it 'calls the CreateInterpolatedCollection service' do
        post :create_transition, params: { collection: { saved_scenario_ids: scenario.id } }
        expect(service).to have_received(:call).with(anything, scenario, user)
      end
    end

    context 'when a saved scenario is in a specific version' do
      let(:version) { create(:version) }
      let(:scenario) { create(:saved_scenario, end_year: 2050, user: user, version: version) }
      let(:user) { create(:user) }
      let(:collection) { create(:collection, scenarios_count: 1, version: version) }

      let!(:service) { class_double('CreateInterpolatedCollection').as_stubbed_const }

      before do
        sign_in user

        allow(service).to receive(:call).and_return(ServiceResult.success(collection))
      end

      it 'redirects to the collection' do
        post :create_transition, params: { collection: { saved_scenario_ids: scenario.id } }

        expect(response).to redirect_to(
          collection_path(Collection.last)
        )
      end

      it 'sets the version of the collection' do
        post :create_transition, params: { collection: { saved_scenario_ids: scenario.id } }

        expect(Collection.last.version).to eq(scenario.version)
      end

      it 'calls the CreateInterpolatedCollection service' do
        post :create_transition, params: { collection: { saved_scenario_ids: scenario.id } }
        expect(service).to have_received(:call).with(anything, scenario, user)
      end
    end

    context 'when signed in and given someone elses saved scenario ID' do
      let(:scenario) { create(:saved_scenario, end_year: 2050) }

      before { sign_in create(:user) }

      it 'raises a Not Found error' do
        post(:create_transition, params: { collection: { saved_scenario_ids: scenario.id } })
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when signed in and the CreateInterpolatedCollection service fails' do
      let(:scenario) { create(:saved_scenario, end_year: 2050, user: user) }
      let(:user) { create(:user) }

      let!(:service) { class_double('CreateInterpolatedCollection').as_stubbed_const }

      before do
        sign_in user

        allow(service).to receive(:call).and_return(ServiceResult.failure(
          "That didn't work."
        ))
      end

      it 'fails the request with a 422 code' do
        post :create_transition, params: { collection: { saved_scenario_ids: scenario.id } }
        expect(response.status).to eq(422)
      end

      it 'renders the index' do
        post :create_transition, params: { collection: { saved_scenario_ids: scenario.id } }
        expect(response).to render_template(:new_transition)
      end

      it 'sets the error message in the flash' do
        post :create_transition, params: { collection: { saved_scenario_ids: scenario.id } }
        expect(flash[:alert]).to eq("That didn't work.")
      end

      it 'calls the CreateInterpolatedCollection service' do
        post :create_transition, params: { collection: { saved_scenario_ids: scenario.id } }
        expect(service).to have_received(:call).with(anything, scenario, user)
      end
    end

    context 'when not signed in ' do
      let(:scenario) { create(:saved_scenario, end_year: 2050, user: create(:user)) }
      it 'shows a sign-in prompt' do
        post :create_transition, params: { collection: { saved_scenario_ids: scenario.id } }
        expect(response).to be_redirect
      end
    end
  end

  describe '#destroy' do
    let!(:service) { class_double('DeleteCollection').as_stubbed_const }

    context 'when the collection belongs to the logged-in user' do
      let(:collection) { create(:collection) }

      before do
        allow(service).to receive(:call).and_return(ServiceResult.success)
        sign_in collection.user
      end

      it 'redirects to the collection root' do
        delete :destroy, params: { id: collection.id }
        expect(response).to redirect_to(collections_url)
      end

      it 'calls the DeleteCollection service' do
        delete :destroy, params: { id: collection.id }
        expect(service).to have_received(:call).with(anything, collection)
      end
    end

    context 'when the collection belongs to a different user' do
      let(:collection) { create(:collection) }

      before do
        sign_in create(:user)
      end

      it 'raises RecordNotFound' do
        delete :destroy, params: { id: collection.id }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when not signed in' do
      let(:collection) { create(:collection) }

      it 'shows the sign-in prompt' do
        delete :destroy, params: { id: collection.id }
        expect(response).to be_redirect
      end
    end
  end

  describe 'PUT discard' do
    let(:scenario) { create(:saved_scenario, end_year: 2050, user: user) }
    let(:user) { create(:user) }
    let(:collection) { create(:collection, scenarios_count: 1) }

    before do
      sign_in(collection.user)
    end

    context 'with an owned collection' do
      before do
        post(:discard, params: { id: collection.id })
      end

      it 'redirects to the scenario listing' do
        expect(response).to be_redirect
      end

      it 'soft-deletes the scenario' do
        expect(collection.reload).to be_discarded
      end
    end

    context 'with an unowned collection' do
      before do
        sign_in create(:user)
        post(:discard, params: { id: collection.id })
      end

      it 'returns 404' do
        expect(response).to be_not_found
      end

      it 'does not soft-delete the collection' do
        expect(collection.reload).not_to be_discarded
      end
    end

    context 'with a collection ID that does not exist' do
      before do
        post(:discard, params: { id: 99_999 })
      end

      it 'returns 404' do
        expect(response).to be_not_found
      end
    end
  end

  describe 'PUT undiscard' do
    let(:scenario) { create(:saved_scenario, end_year: 2050, user: user) }
    let(:user) { create(:user) }
    let(:collection) { create(:collection, scenarios_count: 1) }

    before do
      sign_in(collection.user)
    end

    context 'with an owned collection' do
      before do
        collection.discard!
        post(:undiscard, params: { id: collection.id })
      end

      it 'redirects to the collection listing' do
        expect(response).to be_redirect
      end

      it 'removes the soft-deletion of the collection' do
        expect(collection.reload).not_to be_discarded
      end
    end

    context 'with an unowned collection' do
      before do
        collection.discard!
        sign_in create(:user)
        post(:undiscard, params: { id: collection.id })
      end

      it 'returns 404' do
        expect(response).to be_not_found
      end

      it 'does not remove the soft-deletion of the collection' do
        expect(collection.reload).to be_discarded
      end
    end

    context 'with a collection ID that does not exist' do
      before do
        post(:undiscard, params: { id: 99_999 })
      end

      it 'returns 404' do
        expect(response).to be_not_found
      end
    end
  end

  describe 'PUT update' do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }
    let(:collection) { create(:collection, title: 'Old title', user: user) }
    let(:new_title) { 'New title' }

    before do
      sign_in user
    end

    context 'with a valid title' do
      before do
        put :update, params: { id: collection.id, collection: { title: new_title } }, format: :json
      end

      it 'updates the title of the collection' do
        expect(collection.reload.title).to eq(new_title)
      end

      it 'returns the updated collection as JSON' do
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['title']).to eq(new_title)
      end
    end

    context 'with an invalid title' do
      before do
        put :update, params: { id: collection.id, collection: { title: '' } }, format: :json
      end

      it 'does not update the title of the collection' do
        expect(collection.reload.title).to eq('Old title')
      end

      it 'returns an error JSON response' do
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Title can't be blank")
      end
    end

    context 'with a new saved scenario ids sorted acordingly' do
      let(:collection) { create(:collection, title: 'Old title', user: user, interpolation: false) }

      let(:coll_s_scenarios) do
        [ 1, 2, 3 ].map do |order|
          create(
            :collection_saved_scenario,
            collection:,
            saved_scenario: create(:saved_scenario, user:),
            saved_scenario_order: order
          )
        end
      end

      let(:new_order) do
        [ coll_s_scenarios[1].saved_scenario_id, coll_s_scenarios[0].saved_scenario_id ]
      end

      before do
        put(
          :update,
          params: { id: collection.id, collection: { title: 'New title', saved_scenario_ids: new_order } },
          format: :json
        )
      end

      it 'updates the order of the saved scenarios in the collection' do
        expect(collection.reload.saved_scenario_ids).to eq(new_order)
      end
    end

    context 'when the user does not own the collection or have update permissions' do
      before do
        sign_out user
        sign_in other_user
        put :update, params: { id: collection.id, collection: { title: new_title } }, format: :json
      end

      it 'does not update the title of the collection' do
        expect(collection.reload.title).to eq('Old title')
      end

      it 'cannot find the unowned collection' do
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
