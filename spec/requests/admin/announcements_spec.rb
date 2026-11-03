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

    it "creates the default version's announcement switched off on the first visit" do
      sign_in(admin)
      get '/admin/announcement/edit'

      expect(response).to have_http_status(:ok)
      expect(Announcement.sole).to have_attributes(
        active: false, body_en: nil, body_nl: nil, version: Version.default
      )
    end

    it 'creates the announcement of the given version' do
      version = FactoryBot.create(:version, tag: '2027.01')

      sign_in(admin)
      get '/admin/announcement/edit', params: { version: '2027.01' }

      expect(response).to have_http_status(:ok)
      expect(Announcement.sole.version).to eq(version)
    end

    it 'marks the versions whose announcement is shown' do
      FactoryBot.create(:version, tag: '2027.01')
      Announcement.create!(version: Version.default, active: true, body_en: 'Maintenance')

      sign_in(admin)
      get '/admin/announcement/edit', params: { version: '2027.01' }

      shown = Nokogiri::HTML(response.body).css('nav a').to_h { |a| [ a.text.strip, a.css('svg').any? ] }
      expect(shown).to include('#latest' => true, '#2027.01' => false)
    end

    it 'is not found for an unknown version' do
      sign_in(admin)
      get '/admin/announcement/edit', params: { version: '1999.01' }

      expect(response).to have_http_status(:not_found)
      expect(Announcement.count).to eq(0)
    end
  end

  describe 'PUT /admin/announcement' do
    it 'updates the announcement' do
      sign_in(admin)

      put '/admin/announcement', params: {
        announcement: { active: '1', body_en: 'Maintenance', body_nl: 'Onderhoud' }
      }

      expect(response).to redirect_to(edit_admin_announcement_path(version: 'latest'))
      expect(Announcement.active.sole).to have_attributes(version: Version.default, body_en: 'Maintenance')
    end

    it 'updates only the announcement of the given version' do
      version = FactoryBot.create(:version, tag: '2027.01')
      latest = Announcement.create!(version: Version.default, body_en: 'Latest')

      sign_in(admin)

      put '/admin/announcement', params: {
        version: '2027.01',
        announcement: { active: '1', body_en: 'Deleted on release day' }
      }

      expect(response).to redirect_to(edit_admin_announcement_path(version: '2027.01'))
      expect(Announcement.active.sole).to have_attributes(version:, body_en: 'Deleted on release day')
      expect(latest.reload).to have_attributes(active: false, body_en: 'Latest')
    end
  end
end
