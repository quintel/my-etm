require 'rails_helper'

RSpec.describe "API::Collections", type: :request, api: true do
  let(:user) { create(:user) }

  describe 'GET /api/v1/collections' do
    context 'with an access token with the correct scope' do
      let!(:user_collection1) { create(:collection, user:) }
      let!(:user_collection2) { create(:collection, user:) }
      let!(:other_collection) { create(:collection) }

      before do
        get '/api/v1/collections',
          as: :json,
          headers: access_token_header(user, :read)
      end

      it 'returns success' do
        expect(response).to have_http_status(:success)
      end

      it 'returns the collections' do
        expect(JSON.parse(response.body)['collections']).to eq([
          user_collection2.as_json,
          user_collection1.as_json
        ])
      end

      it 'does not contain collections from other users' do
        expect(JSON.parse(response.body)['collections']).not_to include(other_collection.as_json)
      end
    end

    context 'with an access token with the correct scope, but the user does not exist' do
      let(:request) do
        get '/api/v1/collections',
          as: :json,
          headers: access_token_header(user, :read)
      end

      before { user.destroy! }

      it 'creates the user from the access token' do
        expect { request }.to change(User, :count).by(1)
      end

      it 'returns success' do
        request
        expect(response).to have_http_status(:success)
      end
    end

    context 'without an access token' do
      before do
        get '/api/v1/collections', as: :json
      end

      it 'returns not found status' do
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with an access token with the incorrect scope' do
      before do
        get '/api/v1/collections',
          as: :json,
          headers: access_token_header(user, [])
      end

      it 'returns not_found' do
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ------------------------------------------------------------------------------------------------

  describe 'GET /api/v1/collections/:id' do
    let(:collection) { create(:collection, user:) }

    context 'with a valid access token' do
      before do
        get "/api/v1/collections/#{collection.id}",
          as: :json,
          headers: access_token_header(user, :read)
      end

      it 'returns success' do
        expect(response).to have_http_status(:success)
      end

      it 'returns the collection' do
        expect(JSON.parse(response.body)).to eq(collection.as_json)
      end
    end

    context 'without an access token' do
      before do
        get "/api/v1/collections/#{collection.id}", as: :json
      end

      it 'returns forbidden' do
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with an access token with the incorrect scope' do
      before do
        get "/api/v1/collections/#{collection.id}",
          as: :json,
          headers: access_token_header(user, [])
      end

      it 'returns forbidden' do
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when the collection belongs to someone else' do
      let(:different_user) { create(:user) }

      before do
        get "/api/v1/collections/#{collection.id}",
          as: :json,
          headers: access_token_header(different_user, :read)
      end

      it 'returns forbidden' do
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ------------------------------------------------------------------------------------------------

  describe 'POST /api/v1/collections/:id' do
    let(:request) do
      post '/api/v1/collections',
        as: :json,
        params: { collection: collection_attributes },
        headers: headers
    end

    let(:headers) do
      access_token_header(user, :write)
    end

    let(:collection_attributes) do
      {
        area_code: 'nl',
        end_year: 2050,
        scenario_ids: [ 1, 2, 3 ],
        title: 'My collection',
        version: Version.default.tag
      }
    end

    context 'when given a valid access token and data, and the user exists' do
      it 'returns created' do
        request
        expect(response).to have_http_status(:created)
      end

      it 'creates a collection' do
        expect { request }.to change(user.collections, :count).by(1)
      end

      it 'returns the collection' do
        request
        expect(JSON.parse(response.body)).to eq(user.collections.last.as_json)
      end

      it 'sets the scenario IDs' do
        request
        expect(JSON.parse(response.body)['scenario_ids']).to eq([ 1, 2, 3 ])
      end
    end

    context 'when given a valid access token and data, but the user does not exist' do
      before { user.destroy! }

      it 'returns created' do
        request
        expect(response).to have_http_status(:created)
      end

      it 'creates the user' do
        expect { request }.to change(User, :count).by(1)
      end

      it 'creates a collection' do
        expect { request }.to change(Collection, :count).by(1)
      end

      it 'returns the collection' do
        request
        expect(JSON.parse(response.body)).to eq(User.last.collections.last.as_json)
      end
    end

    context 'when given a valid access token and invalid data' do
      before { user.destroy! }

      let(:collection_attributes) { super().except(:version) }

      it 'returns unprocessable entity' do
        request
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not create a collection' do
        expect { request }.not_to change(user.collections, :count)
      end
    end

    context 'when given a token without the scenarios:write scope' do
      before { user.destroy! }

      let(:headers) do
        access_token_header(user, 'scenarios:read')
      end

      it 'returns not_found' do
        request
        expect(response).to have_http_status(:not_found)
      end

      it 'does not create a collection' do
        expect { request }.not_to change(user.collections, :count)
      end
    end
  end

  # ------------------------------------------------------------------------------------------------

  describe 'PUT /api/v1/collections/:id' do
    let(:collection) do
      create(
        :collection,
        area_code: 'nl',
        end_year: 2050,
        title: 'My collection',
        user:
      )
    end

    let(:request) do
      put "/api/v1/collections/#{collection.id}",
        as: :json,
        params: { collection: collection_attributes },
        headers: access_token_header(user, :write)
    end

    let(:collection_attributes) do
      {
        area_code: 'uk',
        end_year: 2060,
        title: 'My updated collection',
        scenario_ids: [ 1000, 2000 ]
      }
    end

    context 'when given a valid access token and data' do
      it 'returns success' do
        request
        expect(response).to have_http_status(:success)
      end

      it 'updates the collection' do
        keys = collection_attributes.keys - [ :scenario_ids ]

        expect { request }
          .to change { collection.reload.attributes.symbolize_keys.slice(*keys) }
          .from(area_code: 'nl', end_year: 2050, title: 'My collection')
          .to(collection_attributes.except(:scenario_ids))
      end

      it 'changes the scenario IDs' do
        request
        expect(JSON.parse(response.body)['scenario_ids']).to eq([ 1000, 2000 ])
      end
    end

    context 'when updating without scenario IDs' do
      let(:collection_attributes) { super().except(:scenario_ids) }

      it 'returns success' do
        request
        expect(response).to have_http_status(:success)
      end

      it 'does not change the scenario IDs' do
        ids = collection.scenarios.pluck(:scenario_id).sort

        request
        expect(JSON.parse(response.body)['scenario_ids']).to eq(ids)
      end
    end

    context 'when given invalid data' do
      let(:collection_attributes) do
        super().merge(title: '')
      end

      it 'returns unprocessable entity' do
        request
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when the collection belongs to a different user' do
      let(:request) do
        put "/api/v1/collections/#{collection.id}",
          as: :json,
          params: { collection: collection_attributes },
          headers: access_token_header(create(:user), :write)
      end

      it 'returns forbidden' do
        request
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ------------------------------------------------------------------------------------------------

  describe 'DELETE /api/v1/collections/:id' do
    let!(:collection) { create(:collection, user:) }

    context 'when the collection belongs to the user' do
      let(:request) do
        delete "/api/v1/collections/#{collection.id}",
          as: :json,
          headers: access_token_header(user, :delete)
      end

      it 'returns success' do
        request
        expect(response).to have_http_status(:success)
      end

      it 'removes the collection' do
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

    context 'when the collection belongs to a different user' do
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
