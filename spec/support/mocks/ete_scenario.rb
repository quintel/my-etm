# frozen_string_literal: true

# rubocop:disable RSpec/VerifiedDoubles
def ete_scenario_mock
  mock = double('api_scenario')

  stub_basic_attributes(mock)
  stub_timestamps(mock)
  stub_relationships(mock)
  stub_additional_attributes(mock)

  mock
end

def stub_basic_attributes(mock)
  allow(mock).to receive(:id).and_return('123')
  allow(mock).to receive(:title).and_return('title')
  allow(mock).to receive(:description).and_return('description')
  allow(mock).to receive(:end_year).and_return('2050')
  allow(mock).to receive(:area_code).and_return('nl')
end

def stub_timestamps(mock)
  allow(mock).to receive(:created_at) { Time.now.utc }
  allow(mock).to receive(:updated_at) { Time.now.utc }
end

def stub_relationships(mock)
  allow(mock).to receive(:coupled?).and_return(false)
  allow(mock).to receive(:active_couplings).and_return([])
  allow(mock).to receive(:inactive_couplings).and_return([])
end

def stub_additional_attributes(mock)
  allow(mock).to receive(:all_inputs).and_return({})
  allow(mock).to receive(:days_old).and_return(1)
  allow(mock).to receive(:errors).and_return([])
  allow(mock).to receive(:scaling).and_return(nil)
  allow(mock).to receive(:keep_compatible?).and_return(false)
  allow(mock).to receive(:esdl_exportable).and_return(false)
  allow(mock).to receive(:user_values) do
    double('user_values', attributes: { foo: :bar })
  end
end
# rubocop:enable RSpec/VerifiedDoubles
