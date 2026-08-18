# frozen_string_literal: true

# Shared envelope-kind checks for Api::V2::Serialisable's render_* helpers. Reusable by any
# controller spec whose action under test emits that kind - each just asserts `response`, already
# set by the including spec's own request/action, matches the kind's status and shape.
#
# Usage:
#
#   it_behaves_like 'a v2 resource response'
RSpec.shared_examples('a v2 resource response') do
  it 'renders the single-resource kind' do
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to validate_against_the_v2_envelope(:resource)
  end
end

RSpec.shared_examples('a v2 collection response') do
  it 'renders the collection kind' do
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to validate_against_the_v2_envelope(:collection)
  end
end

RSpec.shared_examples('a v2 batch response') do
  it 'renders the batch kind as 207, regardless of mixed outcomes' do
    expect(response).to have_http_status(:multi_status)
    expect(response.parsed_body).to validate_against_the_v2_envelope(:batch)
  end
end

RSpec.shared_examples('a v2 accepted response') do
  it 'renders the accepted kind' do
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('data', 'status')).to eq('accepted')
    expect(response.parsed_body).to validate_against_the_v2_envelope(:accepted)
  end
end

RSpec.shared_examples('a v2 error response') do
  it 'renders the error kind with a stable code and no data key' do
    expect(response.parsed_body['data']).to be_nil
    expect(response.parsed_body).to validate_against_the_v2_envelope(:error)
  end
end

# For show endpoints
#
# Expects the following declared:
#     let(:owner)      { create(:user) }
#     let(:resource)   { create(:collection, user: owner) }
#     let(:path)       { "/api/v2/collections/#{resource.id}" }
#     let(:serialiser) { Api::V2::CollectionSerialiser }
RSpec.shared_examples('a serialisable resource') do
  before do
    get(path, headers: v2_bearer(owner), as: :json)
  end

  it 'puts an object in the data field' do
    expect(response.parsed_body['data']).to be_a(Hash)
  end

  it 'renders exactly the serialiser allow-list, never the model as_json' do
    expect(response.parsed_body['data']).to eq(JSON.parse(serialiser.new(resource).to_json))
  end
end

# For create endpoints
#
# Expects the following declared:
#
#     let(:owner)    { create(:user) }
#     let(:path)     { "/api/v2/collections" }
#
#     let(:required_strict_attribute) { :version }
#     let(:resource_attributes) do
#       {
#         area_code: 'nl',
#         end_year: 2050,
#         scenario_ids: [ 1, 2, 3 ],
#         title: 'My collection',
#         version: Version.default.tag
#       }
#     end
RSpec.shared_examples('a serialisable resource on create') do
  before do
    post(
      path,
      headers: v2_bearer(owner),
      params: { class_sym => resource_attributes },
      as: :json
    )
  end

  context 'with all valid attributes' do
    it 'contains resource details in the data field' do
      expect(response.parsed_body['data'].keys).to include('id')
    end

    it 'does not contain an error field' do
      expect(response.parsed_body['errors']).to be_nil
    end
  end

  context 'when an attribute is missing' do
    let(:resource_attributes) { super().except(required_attribute) }

    it 'does not contain the data field' do
      expect(response.parsed_body['data']).to be_nil
    end

    it 'contains an error field' do
      expect(response.parsed_body['errors']).not_to be_nil
    end

    it 'contains resource errors in the error field' do
      expect(response.parsed_body['errors'].first).to be_a(Hash)
    end

    it 'contains validation error code in the error field' do
      expect(response.parsed_body['errors'].first['code']).to eq("validation_failed")
    end

    it 'points to the failed attribute in the error field' do
      expect(response.parsed_body['errors'].first['source']['pointer']).to eq(required_attribute.to_s)
    end

    it 'contains missing details in the error field' do
      expect(response.parsed_body['errors'].first["detail"]).to eq("is missing")
    end
  end

  context 'when an attribute has an invalid value' do
    let(:resource_attributes) do
      attrs = super()
      attrs[strict_attribute] = :winnie_the_pooh

      attrs
    end

    it 'does not contain the data field' do
      expect(response.parsed_body['data']).to be_nil
    end

    it 'contains an error field' do
      expect(response.parsed_body['errors']).not_to be_nil
    end

    it 'contains resource errors in the error field' do
      expect(response.parsed_body['errors'].first).to be_a(Hash)
    end

    it 'contains validation error code in the error field' do
      expect(response.parsed_body['errors'].first['code']).to eq("validation_failed")
    end

    it 'points to the failed attribute in the error field' do
      expect(response.parsed_body['errors'].first['source']['pointer']).to eq(strict_attribute.to_s)
    end
  end
end

# For update endpoints
#
# Expects the following declared:
#
#     let(:owner)    { create(:user) }
#     let(:resource) { create(:collection, user: owner) }
#     let(:path)     { "/api/v2/collections/:id" }
#
#     let(:unupdateable_attribute) { :version }
#     let(:strict_attribute) { :end_year }
#     let(:resource_attributes) do
#       { title: 'My new collection' }
#     end
RSpec.shared_examples('a serialisable resource on update') do
  before do
    put(
      path,
      headers: v2_bearer(owner),
      params: { class_sym => resource_attributes },
      as: :json
    )
  end

  context 'with all valid attributes' do
    it 'contains resource details in the data field' do
      key = resource_attributes.keys.first
      expect(response.parsed_body['data'][key.to_s]).to eq(resource_attributes[key].to_s)
    end
  end

  context 'when an attribute is not updateable' do
    context 'when only updating that attribute' do
      let(:resource_attributes) { { unupdateable_attribute => :winnie_the_pooh } }

      it 'does not contain a data field' do
        pending 'awaiting code - response for non-existing attributes'
        expect(response.parsed_body['data']).to be_nil
      end

      it 'contains an error field' do
        pending 'awaiting code - response for non-existing attributes'
        expect(response.parsed_body['errors']).not_to be_nil
      end

      it 'contains resource errors in the error field' do
        pending 'awaiting code - response for non-existing attributes'
        expect(response.parsed_body['errors'].first).to be_a(Hash)
      end

      it 'contains validation error code in the error field' do
        pending 'awaiting code - response for non-existing attributes'
        expect(response.parsed_body['errors'].first['code']).to be_a("validation_failed")
      end

      it 'points to the failed attribute in the error field' do
        pending 'awaiting code - response for non-existing attributes'
        expect(response.parsed_body['errors'].first['source']['pointer']).to eq(unupdateable_attribute.to_s)
      end
    end

    context 'when updating a valid attribute as well' do
      let(:resource_attributes) do
        attrs = super()
        attrs[unupdateable_attribute] = :winnie_the_pooh

        attrs
      end

      it 'does not contain a data field' do
        pending 'awaiting code - response for non-existing attributes'
        expect(response.parsed_body['data']).to be_nil
      end

      it 'contains an error field' do
        pending 'awaiting code - response for non-existing attributes'
        expect(response.parsed_body['errors']).not_to be_nil
      end

      it 'contains resource errors in the error field' do
        pending 'awaiting code - response for non-existing attributes'
        expect(response.parsed_body['errors'].first).to be_a(Hash)
      end

      it 'contains validation error code in the error field' do
        pending 'awaiting code - response for non-existing attributes'
        expect(response.parsed_body['errors'].first['code']).to be_a("validation_failed")
      end

      it 'points to the failed attribute in the error field' do
        pending 'awaiting code - response for non-existing attributes'
        expect(response.parsed_body['errors'].first['source']['pointer']).to eq(unupdateable_attribute.to_s)
      end
    end
  end

  context 'when an attribute has an invalid value' do
    let(:resource_attributes) do
      attrs = super()
      attrs[strict_attribute] = :winnie_the_pooh

      attrs
    end

    it 'contains an error field' do
      expect(response.parsed_body['errors']).not_to be_nil
    end

    it 'contains resource errors in the error field' do
      expect(response.parsed_body['errors'].first).to be_a(Hash)
    end

    it 'contains validation error code in the error field' do
      expect(response.parsed_body['errors'].first['code']).to eq("validation_failed")
    end

    it 'points to the failed attribute in the error field' do
      expect(response.parsed_body['errors'].first['source']['pointer']).to eq(strict_attribute.to_s)
    end
  end

  context 'when an attribute does not exist' do
    let(:resource_attributes) { { winnie_the_pooh: :winnie_the_pooh } }

    it 'contains an error field' do
      pending 'awaiting code - response for non-existing attributes'
      expect(response.parsed_body['errors']).not_to be_nil
    end

    it 'contains resource errors in the error field' do
      pending 'awaiting code - response for non-existing attributes'
      expect(response.parsed_body['errors'].first).to be_a(Hash)
    end

    it 'points to the failed attribute in the error field' do
      pending 'awaiting code - response for non-existing attributes'
      expect(response.parsed_body['errors'].first['source']['pointer']).to eq('winnie_the_pooh')
    end
  end
end

# For index endpoints
#
# Expects the following declared:
#     let(:owner)      { create(:user) }
#     let(:path)       { "/api/v2/collections" }
#     let(:class_sym)  { :collection }
#     let(:serialiser) { Api::V2::CollectionSerialiser }
#
# class_sym is used to Factory create different sizes of user resources
RSpec.shared_examples('a collection of serialisable resources') do
  before do
    resources

    get(path, headers: v2_bearer(owner), as: :json)
  end

  context 'with multiple owned resources' do
    let(:resources) { create_list(class_sym, 5, user: owner) }

    it 'renders each entry through the serialiser, never the model as_json' do
      expect(response.parsed_body['data']).to include(JSON.parse(serialiser.new(resources.first).to_json))
    end

    it 'contains exactly the amount of owned resources' do
      expect(response.parsed_body['data'].count).to eq(resources.count)
    end
  end

  context 'with no owned resources' do
    let(:resources) { }

    it 'contains no data in the data field' do
      expect(response.parsed_body['data'].count).to be_zero
    end
  end
end

# For delete endpoints
#
# Expects the following declared:
#     let(:owner)    { create(:user) }
#     let(:resource) { create(:collection, user: owner) }
#     let(:path)     { "/api/v2/collections/#{resource.id}" }
RSpec.shared_examples('a serialisable resource on delete') do
  before do
    delete(path, headers: v2_bearer(owner), as: :json)
  end

  context 'when the owner of the scenario' do
    it 'puts an object in the data field' do
      expect(response.parsed_body['data']).to be_nil
    end
  end
end
