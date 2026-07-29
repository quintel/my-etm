require 'rails_helper'

RSpec.describe "Api::V2::Collections", type: :request, api: true do
  # TODO create this for all endpoints:
  # include_examples 'resource_access'

  let(:user) { create(:user) }

  describe 'GET /api/v2/collections/:id' do
    # include examples on Class name, they can use the factories directly
    # include_examples 'resource_access', url, Collection, user
    #
    # TODO: figure out how to structure this - handover user vs creating in example?
    it_behaves_like 'single_serialisable', "/api/v1/collections/", :collection, user
  end
end
