require 'rails_helper'

RSpec.describe 'API::V1::Versions', type: :request do
  let(:user) { create(:user) }

  describe 'GET /api/v1/versions' do
    before do
      get '/api/v1/versions',
        as: :json,
        headers: access_token_header(user, :read)
    end

    it 'returns a successful response' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns all versions with their URLs' do
      parsed_response = JSON.parse(response.body)

      expect(parsed_response['versions']).to be_present
      expect(parsed_response['versions'].map { |v| v['version'] }).to match_array(Version.all)
      expect(parsed_response['versions'].first).to have_key('url')
      puts parsed_response
    end
  end
end
