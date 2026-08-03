# frozen_string_literal: true

# Shared serialiser tests for API::V2 endpoints.
#
# Each including group supplies:
#
#   owner    - the user the resource belongs to
#   resource - the resource under test, belonging to `owner`
#   path     - the request path for that resource
#
# and, for the write/delete groups, `body` (the params to send).
#
# Usage:
#
#   it_behaves_like 'a read-protected resource' do
#     let(:owner)    { create(:user) }
#     let(:resource) { create(:collection, user: owner) }
#     let(:path)     { "/api/v2/collections/#{resource.id}" }
#   end

# For show endpoints
#
# Expects the following declared:
#     let(:owner)    { create(:user) }
#     let(:resource) { create(:collection, user: owner) }
#     let(:path)     { "/api/v2/collections/#{resource.id}" }
RSpec.shared_examples('a serialisable resource') do
  before do
    get(path, headers: v2_session_cookie(owner), as: :json)
  end

  it 'puts an object in the data field' do
    expect(response.parsed_body['data']).to be_a(Hash)
  end

  it 'contains resource details in the data field' do
    expect(response.parsed_body['data']).to eq(resource.as_json)
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
      headers: v2_session_cookie(owner),
      params: { class_sym => resource_attributes },
      as: :json
    )
  end

  context 'with all valid attributes' do
    it 'contains resource details in the data field' do
      expect(response.parsed_body['data'].keys).to include('id')
    end

    it 'does not contain an error field' do
      expect(response.parsed_body.keys).not_to include('errors')
    end
  end

  context 'when an attribute is missing' do
    let(:resource_attributes) { super().except(required_strict_attribute) }

    it 'does not contain missing attribute in the data field' do
      expect(response.parsed_body['data'].keys).not_to include(required_strict_attribute.to_s)
    end

    it 'does not contain a resource id in the data field' do
      expect(response.parsed_body['data'].keys).not_to include('id')
    end

    it 'contains resource errors in the error field' do
      expect(response.parsed_body['errors']).to include('missing')
    end
  end

  context 'when an attribute has an invalid value' do
    let(:resource_attributes) do
      attrs = super()
      attrs[required_strict_attribute] = :winnie_the_pooh

      attrs
    end

    it 'contains supplied resource details in the data field' do
      expect(response.parsed_body['data'].keys).to include(required_strict_attribute.to_s)
    end

    it 'does not contain a resource id in the data field' do
      expect(response.parsed_body['data'].keys).not_to include('id')
    end

    it 'contains resource errors in the error field' do
      expect(response.parsed_body['errors']).to include('invalid')
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
      headers: v2_session_cookie(owner),
      params: { class_sym => resource_attributes },
      as: :json
    )
  end

  context 'with all valid attributes' do
    it 'contains resource details in the data field' do
      expect(response.parsed_body['data'].keys).to include('id')
    end
  end

  context 'when an attribute is not updateable' do
    context 'when only updating that attribute' do
      let(:resource_attributes) { { unupdateable_attribute: :winnie_the_pooh } }

      it 'contains the original value of the attribute in the data field' do
        expect(response.parsed_body['data'][unupdateable_attribute.to_s]).not_to eq(:winnie_the_pooh)
      end

      it 'contains a resource id in the data field' do
        expect(response.parsed_body['data'].keys).to include('id')
      end

      it 'contains resource errors in the error field' do
        expect(response.parsed_body['errors']).to include('invalid')
      end
    end

    context 'when updating multiple attributes' do
      let(:resource_attributes) do
        attrs = super()
        attrs[unupdateable_attribute] = :winnie_the_pooh

        attrs
      end

      it 'contains the original value of the attribute in the data field' do
        expect(response.parsed_body['data'][unupdateable_attribute.to_s]).not_to eq(:winnie_the_pooh)
      end

      it 'contains the updated value of the other attribute in the data field' do
        key = resource_attributes.keys.excluding(unupdateable_attribute).first
        expect(response.parsed_body['data'][key.to_s]).to eq(resource_attributes[key])
      end

      it 'contains resource errors in the error field' do
        expect(response.parsed_body['errors']).to include('invalid')
      end
    end
  end

  context 'when an attribute has an invalid value' do
    let(:resource_attributes) do
      attrs = super()
      attrs[strict_attribute] = :winnie_the_pooh

      attrs
    end

    it 'contains the original value of the attribute in the data field' do
      expect(response.parsed_body['data'][strict_attribute.to_s]).not_to eq(:winnie_the_pooh)
    end

    it 'contains a resource id in the data field' do
      expect(response.parsed_body['data'].keys).to include('id')
    end

    it 'contains resource errors in the error field' do
      expect(response.parsed_body['errors']).to include('invalid')
    end
  end

  context 'when an attribute does not exist' do
    let(:resource_attributes) { { winnie_the_pooh: :winnie_the_pooh } }

    it 'does not contain unexisting attribute in the data field' do
      expect(response.parsed_body['data'].keys).not_to include('winnie_the_pooh')
    end

    it 'contains resource errors in the error field' do
      expect(response.parsed_body['errors']).to include('invalid')
    end
  end
end

# For index endpoints
#
# Expects the following declared:
#     let(:owner)    { create(:user) }
#     let(:path)     { "/api/v2/collections" }
#     let(:class_sym) { :collection }
#
# class_sym is used to Factory create different sizes of user resources
RSpec.shared_examples('a collection of serialisable resources') do
  before do
    get(path, headers: v2_session_cookie(owner), as: :json)
  end

  context 'with multiple owned resources' do
    let(:resources) { create_list(:class_sym, 5, user: owner) }

    it 'contains resource details in the data field' do
      expect(response.parsed_body['data']).to include(resources.first.to_json)
    end

    it 'contains exactly the amount of owned resources' do
      expect(response.parsed_body['data'].count).to eq(resources.count)
    end
  end

  context 'with no owned resources' do
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
    delete(path, headers: v2_session_cookie(owner), as: :json)
  end

  context 'when the owner of the scenario' do
    it 'puts an object in the data field' do
      expect(response.parsed_body['data']).to be_a(Hash)
    end

    it 'contains resource details in the data field' do
      expect(response.parsed_body['data']).to eq(resource.as_json)
    end

    it 'contains status in the status field' do
      expect(response.parsed_body['status']).to eq('deleted')
    end
  end
end
