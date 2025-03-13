# frozen_string_literal: true

require 'rails_helper'

describe SavedScenarioHistoryPresenter do
  subject { described_class.present(saved_scenario, api_response) }

  let(:api_response) do
    {
      '123' => {
        'id' => 2,
        'user_id' => user.id,
        'description'  => 'added some buildings',
        'last_updated_at' => 2.hours.ago.to_json
      },
      '111' => {
        'last_updated_at' =>  2.days.ago.to_json
      },
      '122' => {
        'id' => 1,
        'user_id' => user.id,
        'description' => 'adjusted wind turbines',
        'last_updated_at' =>  1.day.ago.to_json
      }
    }
  end

  let(:user) { create(:user) }
  let(:saved_scenario) {
 create(:saved_scenario, scenario_id: 123, scenario_id_history: [ 111, 122 ]) }

  it 'returns SavedScenarioHistory objects' do
    expect(subject.first).to be_a(SavedScenarioHistory)
  end

  it 'returns the versions sorted from current to last' do
    expect(subject.map(&:scenario_id)).to eq([ 123, 122, 111 ])
  end

  it 'subsitutes the user id for a users name' do
    expect(subject.first.user_name).to eq(user.name)
  end

  it 'sets frozen' do
    expect(subject.first.frozen).to be_falsey
  end

  it 'sets a "unknown" name when no user was known for the version (older scenario compatability)' do
    expect(subject.last.user_name).to eq('Unknown user')
  end
end
