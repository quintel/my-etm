# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/admin/saved_scenarios', type: :request do
  let(:admin) { FactoryBot.create(:admin) }
  let(:stable) { Version.find_by!(tag: 'stable.01') }
  let(:saved_scenario) { FactoryBot.create(:saved_scenario, version: stable) }
  let(:dump) { instance_double(SavedScenarioPacker::Dump, call: Dry::Monads::Failure('stopped')) }

  describe 'POST /admin/saved_scenarios/batch_dump' do
    before do
      allow(MyEtm::Auth).to receive(:streaming_engine_client).and_return(:stable_client)
      allow(SavedScenarioPacker::Dump).to receive(:new).and_return(dump)
    end

    it "dumps from the ETEngine of the scenarios' version" do
      sign_in(admin)
      post '/admin/saved_scenarios/batch_dump', params: { saved_scenario_ids: [ saved_scenario.id ] }

      expect(MyEtm::Auth).to have_received(:streaming_engine_client).with(admin, stable)
      expect(SavedScenarioPacker::Dump).to have_received(:new)
        .with([ saved_scenario.id.to_s ], :stable_client, admin)
    end
  end
end
