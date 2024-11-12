require 'rails_helper'

RSpec.describe "/admin", type: :request do
  let(:admin) { FactoryBot.create(:admin) }

  pending 'GET index' do
    it 'redirects non admins' do
      get :index
      expect(response).to be_redirect
    end

    it 'works for admins' do
      sign_in(admin)
      get :index
      expect(response).to be_successful
      expect(response).to render_template(:index)
    end
  end
end
