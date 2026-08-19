require 'rails_helper'

RSpec.describe "Api::V2::Collections", type: :request, api: true do
  let(:class_sym)  { :collection }
  let(:owner)      { create(:user) }
  let(:serialiser) { Api::V2::CollectionSerialiser }

  def count_queries
    count = 0
    callback = ->(*) { count += 1 }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }

    count
  end

  # Action: index
  describe 'GET /api/v2/collections' do
    let(:path)      { "/api/v2/collections" }

    it_behaves_like 'a collection of serialisable resources'
    it_behaves_like 'a caller-scoped collection endpoint' do
      let(:resource) { create(:collection, user: owner) }
    end

    it 'lists only the callers own collections, even for an admin' do
      admin = create(:user, admin: true)
      own   = create(:collection, user: admin)
      other = create(:collection, user: owner)

      get(path, headers: v2_bearer(admin, :read), as: :json)

      ids = response.parsed_body['data'].map { |item| item['id'] }
      expect(ids).to eq([ own.id ])
      expect(ids).not_to include(other.id)
    end

    it 'excludes discarded collections' do
      kept      = create(:collection, user: owner)
      discarded = create(:collection, user: owner)
      discarded.discard

      get(path, headers: v2_bearer(owner, :read), as: :json)

      ids = response.parsed_body['data'].map { |item| item['id'] }
      expect(ids).to eq([ kept.id ])
    end

    it 'issues no further query for each additional collection' do
      create_list(:collection, 5, user: owner)
      headers = v2_bearer(owner, :read)
      get(path, headers: headers, as: :json)

      few = count_queries { get(path, headers: headers, as: :json) }
      create_list(:collection, 20, user: owner)
      many = count_queries { get(path, headers: headers, as: :json) }

      expect(many).to eq(few)
    end
  end

  # Action: show
  describe 'GET /api/v2/collections/:id' do
    let(:resource) { create(:collection, user: owner) }
    let(:path)     { "/api/v2/collections/#{resource.id}" }

    it_behaves_like 'a read-protected resource'
    it_behaves_like 'a serialisable resource'

    it 'serialises a collection via the explicit allow-list' do
      get(path, headers: v2_bearer(owner, :read), as: :json)

      expect(response.parsed_body).to validate_against_the_v2_envelope(:resource)
      expect(response.parsed_body['data'].keys).to contain_exactly(
        'id', 'title', 'area_code', 'end_year', 'version', 'interpolation', 'discarded_at',
        'created_at', 'updated_at', 'owner', 'saved_scenario_ids', 'scenario_ids',
        'collections_app_url'
      )
      expect(response.parsed_body.dig('data', 'owner')).to eq('id' => owner.id, 'name' => owner.name)
    end
  end

  # Action: create
  describe 'POST /api/v2/collections' do
    let(:path) { "/api/v2/collections" }

    let(:saved_scenario)     { create(:saved_scenario, user: owner) }
    let(:strict_attribute)   { :end_year }
    let(:required_attribute) { :title }
    let(:resource_attributes) do
      {
        area_code: 'nl2023',
        end_year: 2050,
        saved_scenario_ids: [ saved_scenario.id ],
        title: 'My collection',
        version: Version.default.tag
      }
    end

    it_behaves_like 'a serialisable resource on create'
    it_behaves_like 'a persistant resource on create' do
      let(:resource_name) { :collections }
    end

    it 'is refused, not hidden, with only the read scope' do
      post(path, headers: v2_bearer(owner, :read), params: { collection: resource_attributes }, as: :json)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig('errors', 0, 'code')).to eq('forbidden')
    end

    it 'is told to authenticate when signed out, rather than refused' do
      post(path, params: { collection: resource_attributes }, as: :json)

      expect(response).to have_http_status(:unauthorized)
    end

    it 'ignores scenario_ids, which v2 does not accept as a membership parameter' do
      post(
        path,
        headers: v2_bearer(owner, :write),
        params: { collection: resource_attributes.merge(scenario_ids: [ 1, 2, 3 ]) },
        as: :json
      )

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig('data', 'scenario_ids')).to eq([])
      expect(response.parsed_body.dig('data', 'saved_scenario_ids')).to eq([ saved_scenario.id ])
    end

    it 'answers 400 param_missing when no members are given' do
      post(path, headers: v2_bearer(owner, :write), params: { collection: { title: 'T' } }, as: :json)

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:error)
      expect(response.parsed_body.dig('errors', 0, 'code')).to eq('param_missing')
      expect(response.parsed_body.dig('errors', 0, 'source', 'pointer'))
        .to eq('/collection/saved_scenario_ids')
    end

    it 'points a failing member at its own position, not at the whole list' do
      post(
        path,
        headers: v2_bearer(owner, :write),
        params: { collection: resource_attributes.merge(saved_scenario_ids: [ -1 ]) },
        as: :json
      )

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:error)
      expect(response.parsed_body['errors'].first).to include(
        'code' => 'validation_failed',
        'detail' => 'must be greater than 0',
        'source' => { 'pointer' => '/collection/saved_scenario_ids/0' }
      )
    end

    it 'accepts interpolation on create' do
      post(
        path,
        headers: v2_bearer(owner, :write),
        params: { collection: resource_attributes.merge(interpolation: true) },
        as: :json
      )

      expect(response.parsed_body.dig('data', 'interpolation')).to be(true)
    end

    it 'creates a plain collection when interpolation is not mentioned' do
      post(path, headers: v2_bearer(owner, :write), params: { collection: resource_attributes }, as: :json)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig('data', 'interpolation')).to be(false)
    end

    it 'accepts more than one member without being told about interpolation' do
      members = create_list(:saved_scenario, 3, user: owner, version: Version.default)

      post(
        path,
        headers: v2_bearer(owner, :write),
        params: { collection: resource_attributes.merge(saved_scenario_ids: members.map(&:id)) },
        as: :json
      )

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig('data', 'saved_scenario_ids')).to eq(members.map(&:id))
    end

    it 'refuses more than one member for a transition path, pointed at the member list' do
      members = create_list(:saved_scenario, 2, user: owner, version: Version.default)

      post(
        path,
        headers: v2_bearer(owner, :write),
        params: {
          collection: resource_attributes.merge(
            interpolation: true, saved_scenario_ids: members.map(&:id)
          )
        },
        as: :json
      )

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors'].first).to include(
        'detail' => 'interpolated collections cannot have more than 1 saved scenario',
        'source' => { 'pointer' => '/collection/saved_scenario_ids' }
      )
    end

    it 'points an unresolvable member at its own position rather than raising' do
      post(
        path,
        headers: v2_bearer(owner, :write),
        params: {
          collection: resource_attributes.merge(
            saved_scenario_ids: [ saved_scenario.id, 999_999_999 ]
          )
        },
        as: :json
      )

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:error)
      expect(response.parsed_body['errors']).to contain_exactly(
        hash_including(
          'code' => 'validation_failed',
          'detail' => 'Saved scenario not found',
          'source' => { 'pointer' => '/collection/saved_scenario_ids/1' }
        )
      )
    end

    it 'reports a version mismatch with the version tag, not the Version object' do
      other_version = Version.where.not(id: Version.default.id).first
      mismatched    = create(:saved_scenario, user: owner, version: other_version)

      post(
        path,
        headers: v2_bearer(owner, :write),
        params: { collection: resource_attributes.merge(saved_scenario_ids: [ mismatched.id ]) },
        as: :json
      )

      detail = response.parsed_body.dig('errors', 0, 'detail')
      expect(detail).to include(Version.default.tag)
      expect(detail).not_to match(/#<Version/)
    end

    it 'describes a member it cannot see exactly as it describes an absent one' do
      inaccessible = create(:saved_scenario, user: create(:user), private: true, version: Version.default)

      post(
        path,
        headers: v2_bearer(owner, :write),
        params: { collection: resource_attributes.merge(saved_scenario_ids: [ inaccessible.id ]) },
        as: :json
      )
      hidden = response.parsed_body

      post(
        path,
        headers: v2_bearer(owner, :write),
        params: { collection: resource_attributes.merge(saved_scenario_ids: [ 999_999_999 ]) },
        as: :json
      )

      expect(hidden).to eq(response.parsed_body)
      expect(hidden['errors'].first).to include(
        'detail' => 'Saved scenario not found',
        'source' => { 'pointer' => '/collection/saved_scenario_ids/0' }
      )
    end

    it 'accepts a member the caller holds only a viewer role on' do
      shared = create(:saved_scenario, private: true, version: Version.default)
      create(
        :saved_scenario_user,
        saved_scenario: shared, user: owner, role_id: User::Roles.index_of(:scenario_viewer)
      )

      post(
        path,
        headers: v2_bearer(owner, :write),
        params: { collection: resource_attributes.merge(saved_scenario_ids: [ shared.id ]) },
        as: :json
      )

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig('data', 'saved_scenario_ids')).to eq([ shared.id ])
    end
  end

  # Action: update
  describe 'PUT /api/v2/collections/:id' do
    let(:resource) { create(:collection, user: owner, interpolation: false) }
    let(:path)     { "/api/v2/collections/#{resource.id}" }

    let(:strict_attribute)       { :end_year }
    let(:unupdateable_attribute) { :version }
    let(:resource_attributes) do
      { title: 'My new collection' }
    end

    it_behaves_like 'a write-protected resource' do
      let(:body) { { collection: resource_attributes } }
    end
    it_behaves_like 'a serialisable resource on update'
    it_behaves_like 'a persistant resource on update' do
      let(:resource_name) { :collections }
    end

    it 'does not discard through the general update action' do
      put(path, headers: v2_bearer(owner, :write), params: { collection: { discarded: true } }, as: :json)

      expect(resource.reload.discarded_at).to be_nil
    end

    it 'does not change the version through the general update action' do
      other_version = Version.where.not(id: resource.version_id).first

      put(
        path,
        headers: v2_bearer(owner, :write),
        params: { collection: { version: other_version.tag } },
        as: :json
      )

      expect(resource.reload.version_id).not_to eq(other_version.id)
    end

    it 'does not change interpolation through the general update action' do
      put(path, headers: v2_bearer(owner, :write), params: { collection: { interpolation: true } }, as: :json)

      expect(resource.reload.interpolation).to be(false)
    end

    it 'points an unresolvable member at its own position rather than raising' do
      put(
        path,
        headers: v2_bearer(owner, :write),
        params: { collection: { saved_scenario_ids: [ 999_999_999 ] } },
        as: :json
      )

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to contain_exactly(
        hash_including(
          'detail' => 'Saved scenario not found',
          'source' => { 'pointer' => '/collection/saved_scenario_ids/0' }
        )
      )
    end

    it 'leaves the existing members in place when a new one cannot be resolved' do
      member = create(:saved_scenario, user: owner, version: resource.version)
      resource.update!(saved_scenario_ids: [ member.id ])

      put(
        path,
        headers: v2_bearer(owner, :write),
        params: { collection: { saved_scenario_ids: [ 999_999_999 ] } },
        as: :json
      )

      expect(resource.reload.saved_scenario_ids).to eq([ member.id ])
    end
  end

  # Action: delete
  describe 'DELETE /api/v2/collections/:id' do
    let(:resource) { create(:collection, user: owner) }
    let(:path)     { "/api/v2/collections/#{resource.id}" }

    it_behaves_like 'a delete-protected resource'
    it_behaves_like 'a serialisable resource on delete'
    it_behaves_like 'a persistant resource on delete' do
      let(:resource_name) { :collections }
    end

    it 'hard-deletes and answers 204' do
      delete(path, headers: v2_bearer(owner, :delete), as: :json)

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
      expect(Collection.exists?(resource.id)).to be(false)
    end
  end

  # Action: discard
  describe 'PUT /api/v2/collections/:id/discard' do
    let(:resource) { create(:collection, user: owner) }
    let(:path)     { "/api/v2/collections/#{resource.id}/discard" }

    it 'discards for a caller with the delete scope' do
      put(path, headers: v2_bearer(owner, :delete), as: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:resource)
      expect(resource.reload.discarded_at).not_to be_nil
      expect(response.parsed_body.dig('data', 'discarded_at')).not_to be_nil
    end

    it 'is refused, not hidden, with only the write scope' do
      put(path, headers: v2_bearer(owner, :write), as: :json)

      expect(response).to have_http_status(:forbidden)
      expect(resource.reload.discarded_at).to be_nil
    end

    it 'is hidden to a stranger' do
      put(path, headers: v2_bearer(create(:user), :delete), as: :json)

      expect(response).to have_http_status(:not_found)
    end

    it 'is idempotent' do
      resource.discard

      put(path, headers: v2_bearer(owner, :delete), as: :json)

      expect(response).to have_http_status(:ok)
    end
  end

  # Action: restore
  describe 'PUT /api/v2/collections/:id/restore' do
    let(:resource) { create(:collection, user: owner) }
    let(:path)     { "/api/v2/collections/#{resource.id}/restore" }

    before { resource.discard }

    it 'restores for a caller with the delete scope' do
      put(path, headers: v2_bearer(owner, :delete), as: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:resource)
      expect(resource.reload.discarded_at).to be_nil
    end

    it 'is refused, not hidden, with only the write scope' do
      put(path, headers: v2_bearer(owner, :write), as: :json)

      expect(response).to have_http_status(:forbidden)
      expect(resource.reload.discarded_at).not_to be_nil
    end
  end
end
