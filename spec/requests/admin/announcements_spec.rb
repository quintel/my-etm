# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/admin/announcement', type: :request do
  let(:admin) { FactoryBot.create(:admin) }
  let(:user) { FactoryBot.create(:user) }

  describe 'GET /admin/announcement/edit' do
    it 'is not found for non-admins' do
      sign_in(user)
      get '/admin/announcement/edit'

      expect(response).to have_http_status(:not_found)
    end

    it 'creates the announcement switched off on the first visit' do
      sign_in(admin)
      get '/admin/announcement/edit'

      expect(response).to have_http_status(:ok)
      expect(Announcement.sole).to have_attributes(active: false, body_en: nil, body_nl: nil)
    end
  end

  describe 'PUT /admin/announcement' do
    it 'updates the announcement' do
      sign_in(admin)

      put '/admin/announcement', params: {
        announcement: { active: '1', body_en: 'Maintenance', body_nl: 'Onderhoud' }
      }

      expect(response).to redirect_to(edit_admin_announcement_path)
      expect(Announcement.active.sole.body_en).to eq('Maintenance')
    end
  end
end
