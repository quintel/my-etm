# frozen_string_literal: true

# Shared tests for API::V2 concern of serialisability

RSpec.shared_examples "single_serialisable" do |url, resource_sym, user|
  context 'when owned by the user' do
    let(:resource) { create(resource_sym, user:) }

    before do
      get "/api/v1/collections/#{resource.id}", as: :json
    end

    it 'contains resource details in the data field' do
      expect(JSON.parse(response.body)['data']).to eq(resource.to_json)
    end
  end
end

# Might split up into multiple examples
RSpec.shared_examples "collection_serialisable" do |resources|
  context 'contains one or more resources' do

  end

  context 'was empty' do

  end
end

# Might split up into multiple examples
RSpec.shared_examples "batch_serialisable" do |results|
  context 'all results are a success' do

  end

  context 'all results are failure' do

  end

  context 'results partly failed' do

  end
end
