# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Announcements API', type: :request do
  describe 'GET /api/v1/announcements' do
    before do
      Announcement.create!(active: true, body_en: 'Maintenance', body_nl: 'Onderhoud')
      Announcement.create!(active: false, body_en: 'Not shown')

      get '/api/v1/announcements', as: :json
    end

    it 'returns the active announcements without requiring a token' do
      expect(response).to have_http_status(:ok)

      expect(JSON.parse(response.body)['announcements']).to eq(
        [{ 'body_en' => 'Maintenance', 'body_nl' => 'Onderhoud' }]
      )
    end
  end
end
