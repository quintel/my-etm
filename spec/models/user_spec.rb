# frozen_string_literal: true

RSpec.describe User do
  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to validate_presence_of(:name) }

  it { is_expected.to have_many(:access_grants) }
  it { is_expected.to have_many(:access_tokens) }
  it { is_expected.to have_many(:oauth_applications) }
  it { is_expected.to have_many(:saved_scenarios) }

  describe '.robot' do
    it 'is a confirmed admin' do
      expect(described_class.robot).to have_attributes(admin: true, confirmed?: true)
    end

    it 'is created only once' do
      described_class.robot

      expect { described_class.robot }.not_to change(described_class, :count)
    end
  end

  describe '#valid_password?' do
    let(:user) { create(:user, password: 'password123') }

    context 'with a standard password' do
      it 'returns true when the password is correct' do
        expect(user.valid_password?('password123')).to be(true)
      end

      it 'returns false when the password is incorrect' do
        expect(user.valid_password?('password456')).to be(false)
      end
    end
  end

  context 'when the user is not an admin' do
    let(:roles) { create(:user).roles }

    it 'has the user role' do
      expect(roles).to include('user')
    end

    it 'does not have the admin role' do
      expect(roles).not_to include('admin')
    end
  end

  context 'when the user is an admin' do
    let(:roles) { create(:admin).roles }

    it 'has the user role' do
      expect(roles).to include('user')
    end

    it 'has the admin role' do
      expect(roles).to include('admin')
    end
  end

  context 'when a SavedScenarioUser with the same email existed before the user was created' do
    let(:user) { create(:user, password: 'password123', email: 'foo@bar.com') }

    before do
      ss = create(:saved_scenario)
      create(:saved_scenario_user, user_email: 'foo@bar.com', user_id: nil, saved_scenario: ss)
    end

    it 'couples the new user' do
      expect(user.saved_scenario_users.count).to be_positive
    end

    it 'shows the user has acces to one scenario' do
      expect(user.saved_scenarios.count).to be_positive
    end
  end
end
