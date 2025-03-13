# frozen_string_literal: true

RSpec.describe CreateStaffApplication do
  let(:user) { create(:admin) }

  let(:app_config) do
    MyEtm::StaffApplications::AppConfig.new(
      key: 'my_app',
      name: 'My application',
      uri: 'http://localhost:3002',
      scopes: 'email',
      redirect_path: '/auth',
      config_path: 'conf.yml',
      config_content: ''
    )
  end

  let(:app) { described_class.call(user, app_config).value! }

  # rubocop:disable RSpec/MultipleExpectations
  pending 'when the user does not have a matching application' do
    context 'when creating a new application' do
      it 'increments user.staff_applications count' do
        expect { app }.to change(user.staff_applications, :count).from(0).to(1)
      end

      it 'increments user.oauth_applications count' do
        expect { app }.to change(user.oauth_applications, :count).from(0).to(1)
      end
    end

    context 'when setting default URIs' do
      it 'sets the default application URI' do
        expect(app.application.uri).to eq('http://localhost:3002')
      end

      it 'sets the default redirect URI' do
        expect(app.application.redirect_uri).to eq('http://localhost:3002/auth')
      end
    end

    pending 'when given a custom URI' do
      let(:app) { described_class.call(user, app_config, uri: 'http://myapp.test').value! }

      it 'sets a custom URI and redirect URI' do
        aggregate_failures do
          expect(app.application.uri).to eq('http://myapp.test')
          expect(app.application.redirect_uri).to eq('http://myapp.test/auth')
        end
      end
    end
  end

  pending 'when the user already has the staff application' do
    before { described_class.call(user, app_config) }

    it 'does not create a new application' do
      expect { app }.not_to change(user.staff_applications, :count)
    end

    pending 'when the application URI is different' do
      let(:new_config) { MyEtm::StaffApplications::AppConfig.new(app_config.to_h.merge(url: 'http://wwww.example.org')) }
      let(:oauth_app) { user.staff_applications.find_by!(name: app_config.key).application }

      before { oauth_app.update!(uri: 'http://other-host:3001') }

      it 'does not update the application URI' do
        expect { described_class.call(user, new_config) }
          .not_to change { oauth_app.reload.uri }
          .from('http://other-host:3001')
      end
    end

    pending 'when the application redirect_uri is different' do
      let(:new_config) {
 MyEtm::StaffApplications::AppConfig.new(app_config.to_h.merge(redirect_path: '/auth/callback')) }
      let(:oauth_app) { user.staff_applications.find_by!(name: app_config.key).application }

      before do
        oauth_app.update!(
          uri: 'http://other-host:3001',
          redirect_uri: 'http://other-host:3001/auth'
        )
      end

      it 'updates the application redirect_uri' do
        expect { described_class.call(user, new_config) }
          .to change { oauth_app.reload.redirect_uri }
          .from('http://other-host:3001/auth')
          .to('http://other-host:3001/auth/callback')
      end
    end

    pending 'when the application scope is different' do
      let(:new_config) {
 MyEtm::StaffApplications::AppConfig.new(app_config.to_h.merge(scopes: 'profile')) }
      let(:oauth_app) { user.staff_applications.find_by!(name: app_config.key).application }

      before { oauth_app.update!(scopes: 'openid') }

      it 'updates the scopes of the existing application' do
        expect { described_class.call(user, new_config) }
          .to change { oauth_app.reload.scopes.to_s }
          .from('openid')
          .to('profile')
      end
    end
  end
  # rubocop:enable RSpec/MultipleExpectations
end
