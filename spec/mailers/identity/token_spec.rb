# frozen_string_literal: true

RSpec.describe Identity::TokenMailer, type: :mailer do
  describe 'created_token' do
    let(:user) { create(:user) }
    let(:token) { CreatePersonalAccessToken.call(user:, params: { name: 'test' }).value! }
    let(:mail) { described_class.created_token(token) }

    describe 'renders the headers' do
      it 'has the correct subject' do
        expect(mail.subject).to eq('You created a new token')
      end

      it 'is sent to the correct recipient' do
        expect(mail.to).to eq([ user.email ])
      end

      it 'is sent from the correct address' do
        expect(mail.from).to eq(Mail::Field.parse("From: #{Settings.mailer.from}").addresses)
      end
    end

    describe 'renders the body' do
      it 'includes the main message' do
        expect(mail.body.encoded).to match('You just created a new personal access token')
      end

      it 'includes "- View your public scenarios"' do
        expect(mail.body.encoded).to match('- View your public scenarios')
      end

      it 'includes "- View other people\'s public scenarios"' do
        expect(mail.body.encoded).to match("- View other people's public scenarios")
      end

      it 'does not include "- View your private scenarios"' do
        expect(mail.body.encoded).not_to match('- View your private scenarios')
      end
    end
  end

  describe 'expiring_token' do
    let(:user) { create(:user) }
    let(:token) { CreatePersonalAccessToken.call(user:, params: { name: 'test' }).value! }
    let(:mail) { described_class.expiring_token(token) }

    describe 'renders the headers' do
      it 'has the correct subject' do
        expect(mail.subject).to eq('Your personal access token will expire soon')
      end

      it 'is sent to the correct recipient' do
        expect(mail.to).to eq([ user.email ])
      end

      it 'is sent from the correct address' do
        expect(mail.from).to eq(Mail::Field.parse("From: #{Settings.mailer.from}").addresses)
      end
    end

    describe 'renders the body' do
      it 'includes the expiration warning message' do
        expect(mail.body.encoded).to match('You have an access token which will expire soon')
      end

      it 'includes "- View your public scenarios"' do
        expect(mail.body.encoded).to match('- View your public scenarios')
      end

      it 'includes "- View other people\'s public scenarios"' do
        expect(mail.body.encoded).to match("- View other people's public scenarios")
      end

      it 'does not include "- View your private scenarios"' do
        expect(mail.body.encoded).not_to match('- View your private scenarios')
      end
    end
  end
end
