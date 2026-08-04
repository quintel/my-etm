require 'rails_helper'

RSpec.describe "Api::V2::Collections", type: :request, api: true do
  let(:class_sym) { :collection }
  let(:owner)     { create(:user) }

  # Action: index
  describe 'GET /api/v2/collections' do
    let(:path)      { "/api/v2/collections" }

    it_behaves_like 'a collection of serialisable resources'
    it_behaves_like 'a caller-scoped collection endpoint' do
      let(:resource) { create(:collection, user: owner) }
    end
  end

  # Action: show
  describe 'GET /api/v2/collections/:id' do
    let(:resource) { create(:collection, user: owner) }
    let(:path)     { "/api/v2/collections/#{resource.id}" }

    it_behaves_like 'a read-protected resource'
    it_behaves_like 'a serialisable resource'
  end


  # Action: create
  describe 'POST /api/v2/collections' do
    let(:path)     { "/api/v2/collections" }

    let(:strict_attribute) { :end_year }
    let(:required_attribute) { :title }
    let(:resource_attributes) do
      {
        area_code: 'nl',
        end_year: 2050,
        scenario_ids: [ 1, 2, 3 ],
        title: 'My collection',
        version: Version.default.tag
      }
    end

    it_behaves_like 'a write-protected resource'
    it_behaves_like 'a serialisable resource on create'
    it_behaves_like 'a persistant resource on create' do
      let(:resource_name) { :collections }
    end
  end

  # Action: update
  describe 'PUT /api/v2/collection/:id' do
    let(:resource) { create(:collection, user: owner, interpolation: false) }
    let(:path)     { "/api/v2/collections/#{resource.id}" }

    let(:unupdateable_attribute) { :version }
    let(:strict_attribute) { :end_year }
    let(:resource_attributes) do
      { title: 'My new collection' }
    end

    it_behaves_like 'a write-protected resource'
    it_behaves_like 'a serialisable resource on update'
    it_behaves_like 'a persistant resource on update' do
      let(:resource_name) { :collections }
    end
  end

  # Action: delete
  describe 'DELETE /api/v2/collection/:id' do
    let(:resource) { create(:collection, user: owner) }
    let(:path)     { "/api/v2/collections/#{resource.id}" }

    it_behaves_like 'a delete-protected resource'
    it_behaves_like 'a serialisable resource on delete'
    it_behaves_like 'a persistant resource on delete' do
      let(:resource_name) { :collections }
    end
  end


  # TODO: add other controller actions
  # - discard
  # - restore
end
