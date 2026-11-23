# frozen_string_literal: true

RSpec.describe 'Revoking a personal access token', type: :system do
  {
    en: [
      'Read',
      'Read and write',
      'Read, write and delete'
    ],
    nl: [
      'Lezen',
      'Lezen en bewerken',
      'Lezen, bewerken en verwijderen'
    ]
  }.each do |locale, (read, write, delete)|
    context "with locale=#{locale}" do
      after { I18n.locale = :en } # rubocop:disable Rails/I18nLocaleAssignment

      it 'shows three permission levels, defaulting to read, and no checkboxes' do
        sign_in(create(:user))

        visit "/identity/tokens/new?locale=#{locale}"

        within('form[name="token"]') do
          expect(page).to have_field(type: 'radio', count: 3)
          expect(page).to have_checked_field(read, exact: true)
          expect(page).to have_unchecked_field(write, exact: true)
          expect(page).to have_unchecked_field(delete, exact: true)
          expect(page).to have_no_field(type: 'checkbox')
          expect(page).to have_no_css('.translation_missing')
        end
      end
    end
  end

  context 'with valid params' do
    it 'creates a token' do
      user = create(:user)
      sign_in(user)

      visit '/identity/tokens/new'

      fill_in 'Token name', with: 'API access'
      select '7 days', from: 'Expiration'
      choose 'Read', exact: true

      click_button 'Create token'

      expect(page).to have_content('Token created')
      expect(page).to have_content('API access')

      # Scopes

      expect(page).to have_css(
        '[data-testid="scope:scenarios:read"]:not([aria-hidden="true"])',
        text: 'Read'
      )

      expect(page).to have_css(
        '[data-testid="scope:scenarios:write"][aria-hidden="true"]',
        text: 'Write'
      )

      expect(page).to have_css(
        '[data-testid="scope:scenarios:delete"][aria-hidden="true"]',
        text: 'Delete'
      )
    end
  end

  context 'with no name' do
    it 'creates a token' do
      user = create(:user)
      sign_in(user)

      visit '/identity/tokens/new'

      fill_in 'Token name', with: ''
      select '7 days', from: 'Expiration'
      choose 'Read', exact: true

      click_button 'Create token'

      expect(page).to have_content("Name can't be blank")
    end
  end
end
