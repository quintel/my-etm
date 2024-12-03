require 'rails_helper'

RSpec.describe Api::V1::CollectionsController, type: :controller do
  let(:user) { create(:user) }
  let!(:saved_scenarios) { create_list(:saved_scenario, 2, user: user) }
  let!(:other_saved_scenario) { create(:saved_scenario) }
  let!(:saved_scenario_v2) { create(:saved_scenario, user: user, version: '2.0') }

  describe 'GET #index' do
    let!(:collections) { create_list(:collection, 3, user: user) }
    let!(:discarded_collection) { create(:collection, user: user, discarded_at: Time.current) }

    context 'with an access token with the correct scope' do
      before do
        request.headers.merge!(access_token_header(user, :read))
        get :index, as: :json
      end

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns all kept collections for the current user' do
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['collections'].size).to eq(3)
      end

      it 'does not include discarded collections' do
        parsed_response = JSON.parse(response.body)
        collection_ids = parsed_response['collections'].map { |c| c['id'] }
        expect(collection_ids).not_to include(discarded_collection.id)
      end
    end

    context 'without an access token' do
      before { get :index, as: :json }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST #create' do
    context 'with valid parameters' do
      before do
        request.headers.merge!(access_token_header(user, :write))
      end

      let(:valid_params) do
        {
          collection: {
            title: 'Test Collection',
            version: '1.0',
            saved_scenario_ids: saved_scenarios.map(&:id)
          }
        }
      end

      it 'creates a new collection' do
        expect {
          post :create, params: valid_params, as: :json
        }.to change(Collection, :count).by(1)
      end

      it 'returns the created collection' do
        post :create, params: valid_params, as: :json
        expect(response).to have_http_status(:created)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['title']).to eq('Test Collection')
      end
    end
  end

  before do
    allow_any_instance_of(SavedScenario).to receive(:viewer?).and_return(true)
    allow_any_instance_of(User).to receive(:client_app).and_return(OpenStruct.new(uri: 'http://example.com'))
  end

  describe 'DELETE #destroy' do
    let!(:collection) { create(:collection, user: user) }

    before do
      request.headers.merge!(access_token_header(user, :write))
    end

    context 'when deletion is successful' do
      it 'discards the collection' do
        expect {
          delete :destroy, params: { id: collection.id }, as: :json
        }.to change { collection.reload.discarded? }.from(false).to(true)
      end

      it 'returns no content status' do
        delete :destroy, params: { id: collection.id }, as: :json
        expect(response).to have_http_status(:no_content)
      end
    end

    context 'when deletion fails' do
      before do
        allow_any_instance_of(Collection).to receive(:discard).and_return(false)
        collection.errors.add(:base, 'Cannot discard')
      end

      it 'returns unprocessable entity status' do
        delete :destroy, params: { id: collection.id }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
