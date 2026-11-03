# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Announcements API', type: :request do
  describe 'GET /api/v1/announcements' do
    let(:version) { FactoryBot.create(:version, tag: '2027.01') }

    let(:bodies) { JSON.parse(response.body)['announcements'].pluck('body_en') }

    before do
      Announcement.create!(active: true, version: Version.default, body_en: 'Maintenance', body_nl: 'Onderhoud')
      Announcement.create!(active: true, version:, body_en: 'Deleted on release day')
    end

    it "returns the default version's active announcement without requiring a token" do
      get '/api/v1/announcements', as: :json

      expect(response).to have_http_status(:ok)

      expect(JSON.parse(response.body)['announcements']).to eq(
        [{ 'body_en' => 'Maintenance', 'body_nl' => 'Onderhoud' }]
      )
    end

    it 'returns only the announcement of the given version' do
      get '/api/v1/announcements', params: { version: '2027.01' }

      expect(bodies).to eq([ 'Deleted on release day' ])
    end

    it 'leaves out an inactive announcement' do
      version.announcements.sole.update!(active: false)

      get '/api/v1/announcements', params: { version: '2027.01' }

      expect(bodies).to eq([])
    end

    it 'returns nothing for an unknown version' do
      get '/api/v1/announcements', params: { version: '1999.01' }

      expect(bodies).to eq([])
    end
  end
end
