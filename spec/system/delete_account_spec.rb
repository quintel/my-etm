# frozen_string_literal: true

RSpec.describe 'Registrations', type: :system do
  let(:user) { create(:user) }

  pending 'allows deleting the account' do
    sign_in(user)

    # Create some data for the user.
    create(:scenario, user: user)
    create(:scenario, user: user)
    create(:personal_access_token, user:)

    visit '/identity'

    click_link 'Delete account'

    expect(page).to have_text('You are about to delete your account!')
    expect(page).to have_text('2 scenarios')
    expect(page).to have_text('10 saved scenarios')
    expect(page).to have_text('3 transition paths')
    expect(page).to have_text('One personal access token')

    fill_in 'Password', with: user.password

    begin
      click_button('Permanently delete account')
    rescue ActionController::RoutingError
      # This is raised because it redirects to ETModel, which isn't available in tests.
    end

    expect(User.where(id: user.id).count).to eq(0)
  end

  pending 'shows an error when entering an invalid password' do
    sign_in(user)

    visit '/identity'

    click_link 'Delete account'

    fill_in 'Password', with: '_invalid_'
    click_button 'Permanently delete account'

    expect(page).to have_text('Current password is invalid')
  end

  pending 'shows an error when entering no password' do
    sign_in(user)

    visit '/identity'

    click_link 'Delete account'

    fill_in 'Password', with: ''
    click_button 'Permanently delete account'

    expect(page).to have_text("Current password can't be blank")
  end
end
