require 'spec_helper'

describe UsersController do
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

  pending 'GET edit' do
    it 'redirects guests' do
      get :edit, params: { id: admin.id }
      expect(response).to be_redirect
    end

    context 'when admin is signed in' do
      before do
        sign_in(admin)
        get :edit, params: { id: admin.id }
      end

      it 'returns a successful response' do
        expect(response).to be_successful
      end

      it 'assigns the correct user' do
        expect(assigns(:user)).to eq(admin)
      end

      it 'renders the edit template' do
        expect(response).to render_template(:edit)
      end
    end
  end

  pending 'POST resend_confirmation_email' do
    let(:admin) { create(:admin, :confirmed_at) }
    let(:unconfirmed_user) { create(:user) }
    let(:confirmed_user) { create(:user, :confirmed_at) }

    before { sign_in admin }

    pending 'when user is unconfirmed' do
      it 'sends confirmation and welcome emails' do
        expect do
          post(:resend_confirmation_email, params: { id: unconfirmed_user.id })
        end.to change { ActionMailer::Base.deliveries.count }.by(2)
      end

      it 'redirects to users path' do
        post(:resend_confirmation_email, params: { id: unconfirmed_user.id })
        expect(response).to redirect_to(users_path)
      end

      it 'shows a flash notice' do
        post(:resend_confirmation_email, params: { id: unconfirmed_user.id })
        expect(flash[:notice]).to eq("Confirmation email resent to #{unconfirmed_user.email}.")
      end
    end

    pending 'when user is already confirmed' do
      it 'does not send confirmation email' do
        expect do
          post(:resend_confirmation_email, params: { id: confirmed_user.id })
        end.not_to change { ActionMailer::Base.deliveries.count }
      end

      it 'redirects to users path' do
        post(:resend_confirmation_email, params: { id: confirmed_user.id })
        expect(response).to redirect_to(users_path)
      end

      it 'shows a flash notice' do
        post(:resend_confirmation_email, params: { id: confirmed_user.id })
        expect(flash[:notice]).to eq('User is already confirmed.')
      end
    end

    pending 'when user does not exist' do
      it 'does not send confirmation email' do
        expect do
          post(:resend_confirmation_email, params: { id: -1 })
        end.not_to change { ActionMailer::Base.deliveries.count }
      end

      it 'redirects to users path' do
        post(:resend_confirmation_email, params: { id: -1 })
        expect(response).to redirect_to(users_path)
      end

      it 'shows a flash notice' do
        post(:resend_confirmation_email, params: { id: -1 })
        expect(flash[:notice]).to eq('User does not exist.')
      end
    end
  end
  # rubocop:enable RSpec/MultipleExpectations
end
