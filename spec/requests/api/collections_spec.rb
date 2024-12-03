require 'rails_helper'

RSpec.describe "API::Collections", type: :request, api: true do
  let(:user) { create(:user) }
  let!(:saved_scenarios) { create_list(:saved_scenario, 2, user: user) }
  let!(:collection) { create(:collection, user: user) }

  before do
    allow(Settings).to receive(:collections_url).and_return('http://example.com/collections')
  end

  describe 'GET /api/v1/collections' do
    let!(:discarded_collection) { create(:collection, user: user, discarded_at: Time.current) }

    context 'with an access token with the correct scope' do
      before do
        get '/api/v1/collections',
          as: :json,
          headers: access_token_header(user, :read)
      end

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns all kept collections for the current user' do
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['collections'].size).to eq(1)
      end

      it 'does not include discarded collections' do
        parsed_response = JSON.parse(response.body)
        collection_ids = parsed_response['collections'].map { |c| c['id'] }
        expect(collection_ids).not_to include(discarded_collection.id)
      end
    end

    context 'without an access token' do
      before { get '/api/v1/collections', as: :json }

      it 'returns unauthorized status' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/collections' do
    let(:headers) { access_token_header(user, :write) }
    let(:valid_params) do
      {
        collection: {
          title: 'Test Collection',
          version: '1.0',
          saved_scenario_ids: saved_scenarios.map(&:id)
        }
      }
    end

    context 'with valid parameters' do
      let(:request) do
        post '/api/v1/collections',
          as: :json,
          headers: access_token_header(user, :write),
          params: valid_params
      end

      it 'creates a new collection' do
        expect { request }.to change(Collection, :count).by(1)
      end

      it 'returns the created collection' do
        request
        expect(response).to have_http_status(:created)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['title']).to eq('Test Collection')
      end
    end
  end

  describe 'DELETE /api/v1/collections/:id' do
    let!(:collection) { create(:collection, user: user) }

    context 'when the scenario belongs to the user' do
      let(:request) do
        delete "/api/v1/collections/#{collection.id}",
          as: :json,
          headers: access_token_header(user, :delete)
      end

      it 'returns success' do
        request
        expect(response).to have_http_status(:no_content)
      end

      it 'removes the scenario' do
        expect { request }.to change(user.collections, :count).by(-1)
      end
    end

    context 'when missing the scenarios:delete scope' do
      let(:request) do
        delete "/api/v1/collections/#{collection.id}",
          as: :json,
          headers: access_token_header(user, :write)
      end

      it 'returns forbidden' do
        request
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when the scenario belongs to a different user' do
      let(:request) do
        delete "/api/v1/collections/#{collection.id}",
          as: :json,
          headers: access_token_header(create(:user), :delete)
      end

      it 'returns forbidden' do
        request
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
