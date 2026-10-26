# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/admin/versions', type: :request do
  let(:admin) { FactoryBot.create(:admin) }
  let(:user) { FactoryBot.create(:user) }

  describe 'GET /admin/versions' do
    before do
      Version.default
      FactoryBot.create(:version, tag: '2027.01', hidden: true)
      sign_in(admin)
      get '/admin/versions'
    end

    it 'offers to show a hidden version' do
      expect(response.body).to include(
        %(action="#{admin_version_path(Version.find_by!(tag: '2027.01'))}")
      )
    end

    it 'offers no toggle for the default version' do
      expect(response.body).not_to include(%(action="#{admin_version_path(Version.default)}"))
    end
  end

  describe 'GET /admin/versions/new' do
    it 'is not found for non-admins' do
      sign_in(user)
      get '/admin/versions/new'

      expect(response).to have_http_status(:not_found)
    end

    it 'shows the form to admins' do
      sign_in(admin)
      get '/admin/versions/new'

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /admin/versions' do
    context 'when not an admin' do
      before { sign_in(user) }

      it 'is not found' do
        post '/admin/versions', params: { version: { tag: '2027.01', hidden: '1' } }

        expect(response).to have_http_status(:not_found)
      end

      it 'creates no version' do
        expect { post('/admin/versions', params: { version: { tag: '2027.01', hidden: '1' } }) }
          .not_to change(Version, :count)
      end
    end

    context 'with a new tag' do
      before do
        sign_in(admin)
        post '/admin/versions', params: { version: { tag: '2027.01', hidden: '1' } }
      end

      let(:version) { Version.find_by!(tag: '2027.01') }

      it 'creates the hidden version' do
        expect(version.hidden).to be(true)
      end

      it 'shows the client IDs of both applications' do
        expect(response.body).to include(
          *version.oauth_applications.map { |app| "IDENTITY_CLIENT_ID: #{app.uid}" }
        )
      end

      it 'shows the client secrets of both applications' do
        expect(response.body).to include(
          *version.oauth_applications.map { |app| "IDENTITY_CLIENT_SECRET: #{app.secret}" }
        )
      end

      it 'responds with created' do
        expect(response).to have_http_status(:created)
      end
    end

    it 'shows the form again for an invalid tag' do
      sign_in(admin)
      post '/admin/versions', params: { version: { tag: 'stable.03', hidden: '1' } }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /admin/versions/:id' do
    let!(:version) { FactoryBot.create(:version, hidden: true) }

    context 'when not an admin' do
      before do
        sign_in(user)
        patch "/admin/versions/#{version.id}", params: { version: { hidden: 'false' } }
      end

      it 'is not found' do
        expect(response).to have_http_status(:not_found)
      end

      it 'leaves the version hidden' do
        expect(version.reload.hidden).to be(true)
      end
    end

    context 'when an admin shows a hidden version' do
      before do
        sign_in(admin)
        patch "/admin/versions/#{version.id}", params: { version: { hidden: 'false' } }
      end

      it 'redirects to the versions' do
        expect(response).to redirect_to(admin_versions_path)
      end

      it 'shows the version in the version pickers' do
        expect(version.reload.hidden).to be(false)
      end
    end
  end

  describe 'offering to delete a version' do
    let(:version) { CreateVersion.call(tag: '2099.01', owner: admin).value! }

    before { sign_in(admin) }

    it 'offers it for a version nothing belongs to' do
      version
      get '/admin/versions'

      expect(response.body).to include(confirm_destroy_admin_version_path(version))
    end

    it 'does not offer it for a version with saved scenarios' do
      FactoryBot.create(:saved_scenario, version: version)
      get '/admin/versions'

      expect(response.body).not_to include(confirm_destroy_admin_version_path(version))
    end
  end

  describe 'GET /admin/versions/:id/confirm_destroy' do
    let(:version) { CreateVersion.call(tag: '2099.01', owner: admin).value! }

    it 'is not found for non-admins' do
      sign_in(user)
      get confirm_destroy_admin_version_path(version)

      expect(response).to have_http_status(:not_found)
    end

    it 'asks admins to confirm' do
      sign_in(admin)
      get confirm_destroy_admin_version_path(version)

      expect(response.body).to include(I18n.t('admin.versions.confirm_destroy.submit'))
    end

    it 'is not found for a version with collections' do
      FactoryBot.create(:collection, version: version)
      sign_in(admin)
      get confirm_destroy_admin_version_path(version)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /admin/versions/:id' do
    let(:version) { CreateVersion.call(tag: '2099.01', owner: admin).value! }
    let(:application_ids) { version.oauth_applications.ids }

    context 'when an admin deletes a version nothing belongs to' do
      before do
        FactoryBot.create(
          :access_token, application_id: application_ids.first, resource_owner_id: user.id
        )
        sign_in(admin)
        delete admin_version_path(version)
      end

      it 'deletes the version' do
        expect(Version.exists?(version.id)).to be(false)
      end

      it 'deletes its OAuth applications' do
        expect(OAuthApplication.where(id: application_ids)).to be_empty
      end

      it 'deletes the tokens they issued' do
        expect(Doorkeeper::AccessToken.where(application_id: application_ids)).to be_empty
      end

      it 'redirects to the versions' do
        expect(response).to redirect_to(admin_versions_path)
      end
    end

    context 'when the version has saved scenarios' do
      before do
        FactoryBot.create(:saved_scenario, version: version)
        sign_in(admin)
        delete admin_version_path(version)
      end

      it 'is not found' do
        expect(response).to have_http_status(:not_found)
      end

      it 'keeps the version and its applications' do
        expect(version.reload.oauth_applications.count).to eq(2)
      end
    end

    it 'is not found for the default version' do
      sign_in(admin)
      delete admin_version_path(Version.default)

      expect(response).to have_http_status(:not_found)
    end

    it 'is not found for non-admins' do
      sign_in(user)
      delete admin_version_path(version)

      expect(Version.exists?(version.id)).to be(true)
    end
  end

  describe 'GET /admin/versions for non-admins' do
    it 'is not found' do
      sign_in(user)
      get '/admin/versions'

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /admin/versions/:id for non-admins' do
    it 'is not found' do
      version = CreateVersion.call(tag: '2099.01', owner: admin).value!
      sign_in(user)
      delete admin_version_path(version)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'when not signed in' do
    let(:version) { CreateVersion.call(tag: '2099.01', owner: admin).value! }

    it 'creates no version' do
      expect { post('/admin/versions', params: { version: { tag: '2099.02', hidden: '1' } }) }
        .not_to change(Version, :count)
    end

    it 'does not change whether a version is hidden' do
      patch admin_version_path(version), params: { version: { hidden: 'false' } }

      expect(version.reload.hidden).to be(true)
    end

    it 'deletes no version' do
      delete admin_version_path(version)

      expect(Version.exists?(version.id)).to be(true)
    end

    it 'shows no form for a new version' do
      get '/admin/versions/new'

      expect(response.body).not_to include(I18n.t('admin.versions.new.submit'))
    end
  end
end
