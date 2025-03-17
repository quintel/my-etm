require 'rails_helper'

RSpec.describe "/admin", type: :request do
  let(:admin) { FactoryBot.create(:admin) }

  # rubocop:disable RSpec/MultipleExpectations
  pending 'GET index' do
    it 'redirects non-admins' do
      get :index
      expect(response).to be_redirect
    end

    context 'when admin is signed in' do
      before do
        sign_in(admin)
        get :index
      end

      it 'returns a successful response' do
        expect(response).to be_successful
      end

      it 'renders the index template' do
        expect(response).to render_template(:index)
      end
    end
  end
  # rubocop:enable RSpec/MultipleExpectations
end
