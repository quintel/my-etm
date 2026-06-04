# frozen_string_literal: true

require 'rails_helper'
require 'cancan/matchers'

RSpec.describe Ability, type: :model do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:admin) { create(:admin) }

  describe 'discard action permissions' do
    let!(:owned_scenario) do
      create(:saved_scenario).tap do |scenario|
        create(:saved_scenario_user,
               user: user,
               saved_scenario: scenario,
               role_id: User::Roles.index_of(:scenario_owner))
      end
    end

    let!(:other_scenario) do
      create(:saved_scenario).tap do |scenario|
        create(:saved_scenario_user,
               user: other_user,
               saved_scenario: scenario,
               role_id: User::Roles.index_of(:scenario_owner))
      end
    end

    # Create ability after scenarios are created
    subject(:ability) { Ability.new(user) }

    context 'when user is the scenario owner' do
      it 'allows owner to discard their scenarios' do
        expect(ability).to be_able_to(:discard, owned_scenario)
      end

      it 'uses the same permissions as destroy' do
        expect(ability).to be_able_to(:destroy, owned_scenario)
        expect(ability).to be_able_to(:discard, owned_scenario)
      end
    end

    context 'when user is a collaborator' do
      let(:collaborator_scenario) do
        create(:saved_scenario).tap do |scenario|
          # Create owner first to satisfy the "at least one owner" requirement
          create(:saved_scenario_user,
                 user: other_user,
                 saved_scenario: scenario,
                 role_id: User::Roles.index_of(:scenario_owner))
          # Then add user as collaborator
          create(:saved_scenario_user,
                 user: user,
                 saved_scenario: scenario,
                 role_id: User::Roles.index_of(:scenario_collaborator))
        end
      end

      it 'prevents collaborator from discarding scenarios' do
        expect(ability).not_to be_able_to(:discard, collaborator_scenario)
      end
    end

    context 'when user is a viewer' do
      let(:viewer_scenario) do
        create(:saved_scenario).tap do |scenario|
          # Create owner first to satisfy the "at least one owner" requirement
          create(:saved_scenario_user,
                 user: other_user,
                 saved_scenario: scenario,
                 role_id: User::Roles.index_of(:scenario_owner))
          # Then add user as viewer
          create(:saved_scenario_user,
                 user: user,
                 saved_scenario: scenario,
                 role_id: User::Roles.index_of(:scenario_viewer))
        end
      end

      it 'prevents viewer from discarding scenarios' do
        expect(ability).not_to be_able_to(:discard, viewer_scenario)
      end
    end

    context 'when user does not own the scenario' do
      it 'prevents non-owner from discarding scenarios' do
        expect(ability).not_to be_able_to(:discard, other_scenario)
      end
    end

    context 'when user is an admin' do
      subject(:ability) { Ability.new(admin) }

      it 'allows admin to discard any scenario' do
        expect(ability).to be_able_to(:discard, other_scenario)
      end

      it 'allows admin to destroy any scenario' do
        expect(ability).to be_able_to(:destroy, other_scenario)
      end
    end
  end
end
