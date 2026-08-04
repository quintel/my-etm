# frozen_string_literal: true

# Other ETM apps send signed-out visitors here with the page they were trying to reach, so that
# after signing in they land back on that page rather than on MyETM's home page.
RSpec.describe 'Sign-in return_to', type: :request do
  let(:user) { create(:user, :confirmed_at, password: 'password') }

  let(:model_url) { Version.default.model_url }
  let(:collections_url) { Version.default.collections_url }

  def sign_in_with(return_to:)
    get '/identity/sign_in', params: { return_to: return_to }.compact
    post '/identity/sign_in', params: { user: { email: user.email, password: 'password' } }
  end

  it 'returns the user to the page they came from at ETModel' do
    sign_in_with(return_to: "#{model_url}/scenarios/123")

    expect(response).to redirect_to("#{model_url}/scenarios/123")
  end

  it 'returns the user to Collections' do
    sign_in_with(return_to: "#{collections_url}/collections/7")

    expect(response).to redirect_to("#{collections_url}/collections/7")
  end

  it 'starts the shared browser session even when returning to another app' do
    sign_in_with(return_to: "#{model_url}/scenarios/123")

    expect(response.cookies['etm_session']).to be_present
  end

  # An unvalidated return_to would make the ETM sign-in page an open redirect: a phishing link
  # would show the genuine login form, then hand the freshly-authenticated user to the attacker.
  describe 'rejecting targets that are not ETM apps' do
    [
      'https://evil.example.com/steal',
      'https://energytransitionmodel.com.evil.example.com/steal',
      'javascript:alert(1)',
      '//evil.example.com'
    ].each do |hostile|
      it "ignores #{hostile}" do
        sign_in_with(return_to: hostile)

        expect(response).not_to redirect_to(hostile)
        expect(response.location).not_to include('evil.example.com')
      end
    end
  end

  it 'falls back to the default destination when no return_to is given' do
    sign_in_with(return_to: nil)

    expect(response).to have_http_status(:redirect)
    expect(response.location).not_to include('sign_in')
  end

  # Devise's stock guard reads Warden, which is deliberately not persisted (the access cookie is the
  # session of record). Without the override in SessionsController#require_no_authentication, a
  # signed-in visitor hitting the form and a signed-out one being bounced to it can ping-pong.
  describe 'when already signed in' do
    it 'does not render the sign-in form again' do
      sign_in_with(return_to: nil)
      follow_redirect!

      get '/identity/sign_in'

      expect(response).to have_http_status(:redirect)
      expect(response.location).not_to include('/identity/sign_in')
    end
  end
end
