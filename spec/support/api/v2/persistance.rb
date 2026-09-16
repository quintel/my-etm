# frozen_string_literal: true

# Shared persistence checks for Api::V2 endpoints: what reached the database, as opposed to what
# the response said, which is spec/support/api/v2/concerns/responses.rb.
#
# Each group documents the lets it expects.
#
# Usage:
#
#   it_behaves_like 'a persistant resource on update'

# For create endpoints
#
# Expects the following declared:
#     let(:owner)       { create(:user) }
#     let(:owner_assoc) { :collections }
#     let(:path)        { "/api/v2/collections" }
#     let(:class_sym)   { :collection }
#
#     let(:required_attribute) { :title }
#     let(:resource_attributes) do
#       {
#         area_code: 'nl',
#         end_year: 2050,
#         saved_scenario_ids: [ saved_scenario.id ],
#         title: 'My collection',
#         version: Version.default.tag
#       }
#     end
RSpec.shared_examples('a persistant resource on create') do
  subject do
    post(
      path,
      headers: v2_bearer(owner),
      params: { class_sym => resource_attributes },
      as: :json
    )
  end

  context 'with valid create params' do
    it 'increases the users resource count by 1' do
      expect { subject }.to change { owner.public_send(owner_assoc).count }.by(1)
    end
  end

  context 'with invalid create params' do
    let(:resource_attributes) { super().except(required_attribute) }

    it 'increases the users resource count by 1' do
      expect { subject }.not_to change { owner.public_send(owner_assoc).count }
    end
  end
end

# For update endpoints
#
# Expects the following declared:
#     let(:owner)     { create(:user) }
#     let(:resource)  { create(:collection, user: owner) }
#     let(:path)      { "/api/v2/collections/:id" }
#     let(:class_sym) { :collection }
#
#     let(:resource_attributes) do
#       { title: 'My new collection' }
#     end
#
# The context for a member given a value it refuses is a separate shared example: not every
# resource has such a member.
RSpec.shared_examples('a persistant resource on update') do
  subject do
    put(
      path,
      headers: v2_bearer(owner),
      params: { class_sym => resource_attributes },
      as: :json
    )
  end

  before { resource }

  context 'with valid update params' do
    it 'updates the field' do
      expect { subject }.to change { resource.reload.public_send(resource_attributes.keys.first) }
    end
  end

  context 'when not the resource owner' do
    subject do
      put(
        path,
        headers: v2_bearer(other_user),
        params: { class_sym => resource_attributes },
        as: :json
      )
    end

    let(:other_user) { create(:user) }

    it 'does not update the fields' do
      expect { subject }.not_to change { resource }
    end
  end
end

# For an update endpoint whose resource has a member that refuses a value.
# Confirms the whole update is rejected, the valid member included.
#
# Expects the following declared:
#     let(:owner)     { create(:user) }
#     let(:resource)  { create(:collection, user: owner) }
#     let(:path)      { "/api/v2/collections/:id" }
#     let(:class_sym) { :collection }
#
#     let(:resource_attributes) do
#       { title: 'My new collection' }
#     end
#
#     let(:strict_attribute)       { :end_year }
#     let(:strict_attribute_value) { :winnie_the_pooh }
RSpec.shared_examples('a persistant resource that refuses an invalid member') do
  subject do
    put(
      path,
      headers: v2_bearer(owner),
      params: { class_sym => resource_attributes },
      as: :json
    )
  end

  before { resource }

  let(:resource_attributes) do
    attrs = super()
    attrs[strict_attribute] = strict_attribute_value

    attrs
  end

  it 'does not update the field of the valid attirbute' do
    key = resource_attributes.keys.excluding(strict_attribute).first
    expect { subject }.not_to change { resource.public_send(key) }
  end

  it 'does not update the field of the invalid attribute' do
    expect { subject }.not_to change { resource.public_send(strict_attribute) }
  end
end

# For delete endpoints
#
# Expects the following declared:
#     let(:owner)       { create(:user) }
#     let(:owner_assoc) { :collections }
#     let(:resource)    { create(:collection, user: owner) }
#     let(:path)        { "/api/v2/collections/:id" }
#
RSpec.shared_examples('a persistant resource on delete') do
  subject do
    delete(path, headers: v2_bearer(owner), as: :json)
  end

  before { resource }

  context 'when the owner of the resource' do
    it 'decreases the users resource count by 1' do
      expect { subject }.to change { owner.public_send(owner_assoc).count }.by(-1)
    end
  end

  context 'when not the owner of the resource' do
    subject do
      delete(path, headers: v2_bearer(other_user), as: :json)
    end

    let(:other_user) { create(:user) }

    it 'does not remove the resource' do
      expect { subject }.not_to change { owner.public_send(owner_assoc).count }
    end
  end
end
