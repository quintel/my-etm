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
#   it_behaves_like 'a persistant resource on update' do
#     let(:owner)    { create(:user) }
#     let(:resource) { create(:collection, user: owner) }
#     let(:path)     { "/api/v2/collections/#{resource.id}" }
#   end


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
RSpec.shared_examples('a persistant resource on create') do
  subject do
    post(
      path,
      headers: v2_session_cookie(owner),
      params: { class_sym => resource_attributes },
      as: :json
    )
  end

  context 'with valid create params' do
    it 'increases the users resource count by 1' do
      expect { subject }.to change { owner.public_send(resource_name).count }.by(1)
    end
  end

  context 'with invalid create params' do
    let(:resource_attributes) { super().except(required_strict_attribute) }

    it 'increases the users resource count by 1' do
      expect { subject }.not_to change { owner.public_send(resource_name).count }
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
RSpec.shared_examples('a persistant resource on update') do
  subject do
    put(
      path,
      headers: v2_session_cookie(owner),
      params: { class_sym => resource_attributes },
      as: :json
    )
  end

  context 'with valid update params' do
    it 'updates the field' do
      expect { subject }.to change { resource.public_send(resource_attributes.keys.first) }
    end
  end

  context 'with one valid and one invalid param' do
    let(:resource_attributes) do
        attrs = super()
        attrs[strict_attribute] = :winnie_the_pooh

        attrs
      end

    it 'updates the field of the valid attirbute' do
      key = resource_attributes.keys.excluding(strict_attribute).first
      expect { subject }.to change { resource.public_send(key) }
    end

    it 'does not update the field of the invalid attribute' do
      expect { subject }.not_to change { resource.public_send(strict_attribute) }
    end
  end

  context 'when not the resource owner' do
    subject do
      put(
        path,
        headers: v2_session_cookie(other_user),
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

# For delete endpoints
#
# Expects the following declared:
#
#     let(:owner)    { create(:user) }
#     let(:resource) { create(:collection, user: owner) }
#     let(:path)     { "/api/v2/collections/:id" }
#
RSpec.shared_examples('a persistant resource on delete') do
  subject do
    delete(path, headers: v2_session_cookie(owner), as: :json)
  end

  context 'when the owner of the resource' do
    it 'decreases the users resource count by 1' do
      expect { subject }.to change { owner.public_send(resource_name).count }.by(-1)
    end
  end

  context 'when not the owner of the resource' do
    subject do
      delete(path, headers: v2_session_cookie(other_user), as: :json)
    end

    let(:other_user) { create(:user) }

    it 'does not remove the resource' do
      expect { subject }.not_to change { owner.public_send(resource_name).count }
    end
  end
end
