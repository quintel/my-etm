# frozen_string_literal: true

require 'rails_helper'
require 'cancan/matchers'

RSpec.describe Api::TokenAbility do
  # The token scopes will be overridden per context.
  let(:scopes) { "" }
  let(:token)  { { "scopes" => scopes } }
  subject(:ability) { described_class.new(token, user) }

  let(:public_saved_scenario)        { create(:saved_scenario, private: false) }
  let(:private_saved_scenario)       { create(:saved_scenario, private: true) }
  let(:other_public_saved_scenario)  { create(:saved_scenario, private: false) }
  let(:other_private_saved_scenario) { create(:saved_scenario, private: true) }

  let(:user_collection)  { create(:collection, user: user) }
  let(:other_collection) { create(:collection) }

  # Associated users with specific roles for permission testing.
  let(:viewer_user)       { create(:user) }
  let(:collaborator_user) { create(:user) }
  let(:owner_user)        { create(:user) }

  before do
    # For viewer: associate viewer_user with private_saved_scenario as viewer.
    create(:saved_scenario_user,
           user: viewer_user,
           saved_scenario: private_saved_scenario,
           role_id: User::Roles.index_of(:scenario_viewer))
    # For collaborator:
    # Associate collaborator_user with public_saved_scenario as collaborator (for write).
    create(:saved_scenario_user,
           user: collaborator_user,
           saved_scenario: public_saved_scenario,
           role_id: User::Roles.index_of(:scenario_collaborator))
    # Also associate collaborator_user with private_saved_scenario so they inherit viewer rights.
    create(:saved_scenario_user,
           user: collaborator_user,
           saved_scenario: private_saved_scenario,
           role_id: User::Roles.index_of(:scenario_collaborator))
    # For owner:
    # Associate owner_user with private_saved_scenario as owner (for delete).
    create(:saved_scenario_user,
           user: owner_user,
           saved_scenario: private_saved_scenario,
           role_id: User::Roles.index_of(:scenario_owner))
    # Also associate owner_user with public_saved_scenario as collaborator so they have update rights.
    create(:saved_scenario_user,
           user: owner_user,
           saved_scenario: public_saved_scenario,
           role_id: User::Roles.index_of(:scenario_collaborator))
  end

  context 'when the token scope is "public" (no scopes)' do
    let(:user) { create(:user, admin: false) }
    let(:scopes) { "" }
    before { user_collection }

    describe "read abilities" do
      it "allows reading public saved scenarios" do
        expect(ability).to be_able_to(:read, public_saved_scenario)
        expect(ability).to be_able_to(:read, other_public_saved_scenario)
      end

      it "does not allow reading private saved scenarios" do
        expect(ability).not_to be_able_to(:read, private_saved_scenario)
        expect(ability).not_to be_able_to(:read, other_private_saved_scenario)
      end

      it "does not allow reading any collections" do
        expect(ability).not_to be_able_to(:read, user_collection)
        expect(ability).not_to be_able_to(:read, other_collection)
      end
    end

    describe "write abilities" do
      it "does not allow creating or updating saved scenarios" do
        expect(ability).not_to be_able_to(:create, SavedScenario)
        expect(ability).not_to be_able_to(:update, public_saved_scenario)
      end

      it "does not allow creating or updating collections" do
        expect(ability).not_to be_able_to(:create, Collection)
        expect(ability).not_to be_able_to(:update, user_collection)
      end
    end

    describe "delete abilities" do
      it "does not allow destroying any saved scenario" do
        expect(ability).not_to be_able_to(:destroy, public_saved_scenario)
        expect(ability).not_to be_able_to(:destroy, private_saved_scenario)
      end

      it "does not allow destroying any collection" do
        expect(ability).not_to be_able_to(:destroy, user_collection)
      end
    end
  end

  context 'when the token scope is "scenarios:read" as a viewer' do
    let(:user) { viewer_user }
    let(:scopes) { "scenarios:read" }
    before { user_collection }

    describe "read abilities" do
      it "allows reading public saved scenarios" do
        expect(ability).to be_able_to(:read, public_saved_scenario)
        expect(ability).to be_able_to(:read, other_public_saved_scenario)
      end

      it "allows reading private saved scenarios because the user is a viewer" do
        expect(ability).to be_able_to(:read, private_saved_scenario)
      end

      it "does not allow reading private saved scenarios without association" do
        expect(ability).not_to be_able_to(:read, other_private_saved_scenario)
      end

      it "allows reading collections owned by the user" do
        expect(ability).to be_able_to(:read, user_collection)
      end

      it "does not allow reading collections not owned by the user" do
        expect(ability).not_to be_able_to(:read, other_collection)
      end
    end

    describe "write abilities" do
      it "does not allow creating or updating saved scenarios" do
        expect(ability).not_to be_able_to(:create, SavedScenario)
        expect(ability).not_to be_able_to(:update, public_saved_scenario)
      end

      it "does not allow creating or updating collections" do
        expect(ability).not_to be_able_to(:create, Collection)
        expect(ability).not_to be_able_to(:update, user_collection)
      end
    end

    describe "delete abilities" do
      it "does not allow destroying saved scenarios" do
        expect(ability).not_to be_able_to(:destroy, private_saved_scenario)
      end
    end
  end

  context 'when the token scope is "scenarios:read scenarios:write" as a collaborator' do
    let(:user) { collaborator_user }
    let(:scopes) { "scenarios:read scenarios:write" }
    before { user_collection }

    describe "read abilities" do
      it "allows reading public saved scenarios" do
        expect(ability).to be_able_to(:read, public_saved_scenario)
        expect(ability).to be_able_to(:read, other_public_saved_scenario)
      end

      it "allows reading private saved scenarios because the user is a collaborator" do
        expect(ability).to be_able_to(:read, private_saved_scenario)
      end

      it "does not allow reading private saved scenarios without association" do
        expect(ability).not_to be_able_to(:read, other_private_saved_scenario)
      end

      it "allows reading collections owned by the user" do
        expect(ability).to be_able_to(:read, user_collection)
      end

      it "does not allow reading collections not owned by the user" do
        expect(ability).not_to be_able_to(:read, other_collection)
      end
    end

    describe "write abilities" do
      it "allows creating a new saved scenario" do
        expect(ability).to be_able_to(:create, SavedScenario)
      end

      it "allows creating a new collection" do
        expect(ability).to be_able_to(:create, Collection)
      end

      it "allows updating saved scenarios in collaborator scope" do
        expect(ability).to be_able_to(:update, public_saved_scenario)
        expect(ability).to be_able_to(:update, private_saved_scenario)
      end

      it "does not allow updating saved scenarios not in collaborator scope" do
        expect(ability).not_to be_able_to(:update, other_public_saved_scenario)
        expect(ability).not_to be_able_to(:update, other_private_saved_scenario)
      end

      it "allows updating collections owned by the user" do
        expect(ability).to be_able_to(:update, user_collection)
      end

      it "does not allow updating collections not owned by the user" do
        expect(ability).not_to be_able_to(:update, other_collection)
      end
    end

    describe "delete abilities" do
      it "does not allow destroying saved scenarios" do
        expect(ability).not_to be_able_to(:destroy, private_saved_scenario)
      end
    end
  end

  context 'when the token scope is "scenarios:read scenarios:write scenarios:delete" as an owner' do
    let(:user) { owner_user }
    let(:scopes) { "scenarios:read scenarios:write scenarios:delete" }
    before { user_collection }

    describe "read abilities" do
      it "allows reading public saved scenarios" do
        expect(ability).to be_able_to(:read, public_saved_scenario)
        expect(ability).to be_able_to(:read, other_public_saved_scenario)
      end

      it "allows reading private saved scenarios because the user is an owner" do
        expect(ability).to be_able_to(:read, private_saved_scenario)
      end

      it "does not allow reading private saved scenarios without association" do
        expect(ability).not_to be_able_to(:read, other_private_saved_scenario)
      end

      it "allows reading collections owned by the user" do
        expect(ability).to be_able_to(:read, user_collection)
      end

      it "does not allow reading collections not owned by the user" do
        expect(ability).not_to be_able_to(:read, other_collection)
      end
    end

    describe "write abilities" do
      it "allows creating a new saved scenario" do
        expect(ability).to be_able_to(:create, SavedScenario)
      end

      it "allows creating a new collection" do
        expect(ability).to be_able_to(:create, Collection)
      end

      it "allows updating saved scenarios in collaborator scope" do
        expect(ability).to be_able_to(:update, public_saved_scenario)
        expect(ability).to be_able_to(:update, private_saved_scenario)
      end

      it "does not allow updating saved scenarios not in collaborator scope" do
        expect(ability).not_to be_able_to(:update, other_public_saved_scenario)
        expect(ability).not_to be_able_to(:update, other_private_saved_scenario)
      end

      it "allows updating collections owned by the user" do
        expect(ability).to be_able_to(:update, user_collection)
      end

      it "does not allow updating collections not owned by the user" do
        expect(ability).not_to be_able_to(:update, other_collection)
      end
    end

    describe "delete abilities" do
      it "allows destroying saved scenarios in owner scope" do
        expect(ability).to be_able_to(:destroy, private_saved_scenario)
      end

      it "does not allow destroying saved scenarios not in owner scope" do
        expect(ability).not_to be_able_to(:destroy, public_saved_scenario)
        expect(ability).not_to be_able_to(:destroy, other_public_saved_scenario)
        expect(ability).not_to be_able_to(:destroy, other_private_saved_scenario)
      end

      it "allows destroying collections owned by the user" do
        expect(ability).to be_able_to(:destroy, user_collection)
      end

      it "does not allow destroying collections not owned by the user" do
        expect(ability).not_to be_able_to(:destroy, other_collection)
      end
    end
  end

  context 'when the user is an admin' do
    let(:user) { create(:user, admin: true) }
    let(:scopes) { "scenarios:read scenarios:write scenarios:delete" }
    before { user_collection }

    describe "read abilities" do
      it "allows reading all saved scenarios" do
        expect(ability).to be_able_to(:read, public_saved_scenario)
        expect(ability).to be_able_to(:read, private_saved_scenario)
        expect(ability).to be_able_to(:read, other_public_saved_scenario)
        expect(ability).to be_able_to(:read, other_private_saved_scenario)
      end

      it "allows reading all collections" do
        expect(ability).to be_able_to(:read, user_collection)
        expect(ability).to be_able_to(:read, other_collection)
      end
    end

    describe "write abilities" do
      it "allows updating all saved scenarios" do
        expect(ability).to be_able_to(:update, public_saved_scenario)
        expect(ability).to be_able_to(:update, private_saved_scenario)
        expect(ability).to be_able_to(:update, other_public_saved_scenario)
        expect(ability).to be_able_to(:update, other_private_saved_scenario)
      end

      it "allows updating all collections" do
        expect(ability).to be_able_to(:update, user_collection)
        expect(ability).to be_able_to(:update, other_collection)
      end
    end

    describe "delete abilities" do
      it "allows destroying all saved scenarios" do
        expect(ability).to be_able_to(:destroy, public_saved_scenario)
        expect(ability).to be_able_to(:destroy, private_saved_scenario)
        expect(ability).to be_able_to(:destroy, other_public_saved_scenario)
        expect(ability).to be_able_to(:destroy, other_private_saved_scenario)
      end

      it "allows destroying all collections" do
        expect(ability).to be_able_to(:destroy, user_collection)
        expect(ability).to be_able_to(:destroy, other_collection)
      end
    end
  end
end
