# frozen_string_literal: true

# Shared envelope-kind checks for Api::V2::Rendering' render_* helpers. Reusable by any
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

RSpec.shared_examples('a v2 ok response') do
  it 'renders the ok kind' do
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('data', 'status')).to eq('ok')
    expect(response.parsed_body).to validate_against_the_v2_envelope(:ok)
  end
end

RSpec.shared_examples('a v2 no_content response') do
  it 'renders the no_content kind, carrying nothing' do
    expect(response).to have_http_status(:no_content)
    expect(response.body).to validate_against_the_v2_envelope(:no_content)
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
#     owner      - the user the resource belongs to
#     resource   - the record under test
#     path       - the endpoint's path for that record
#     serialiser - the serialiser the endpoint renders with
RSpec.shared_examples('a serialisable resource') do

  let(:serialiser_options) { {} }

  before do
    get(path, headers: v2_bearer(owner), as: :json)
  end

  it 'puts an object in the data field' do
    expect(response.parsed_body['data']).to be_a(Hash)
  end

  it 'renders exactly the serialiser allow-list, never the model as_json' do
    expect(response.parsed_body['data'])
      .to eq(JSON.parse(serialiser.new(resource, **serialiser_options).to_json))
  end
end

# For create endpoints
#
# Expects the following declared:
#     owner               - the user creating the resource
#     path                - the endpoint's path
#     class_sym           - the member the request body wraps the resource in
#     resource_attributes - a body the action accepts
#     required_attribute  - a member the action refuses to do without
#     strict_attribute    - a member that refuses :winnie_the_pooh
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
      expect(response.parsed_body['errors'].first['source']['pointer']).to eq("/#{class_sym}/#{required_attribute}")
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
      expect(response.parsed_body['errors'].first['source']['pointer']).to eq("/#{class_sym}/#{strict_attribute}")
    end
  end
end

# For update endpoints
#
# Expects the following declared:
#     owner               - the user the resource belongs to
#     resource            - the record under test
#     path                - the endpoint's path for that record
#     class_sym           - the member the request body wraps the resource in
#     resource_attributes - a body the action accepts
#
# The contexts for a member the action will not update, and for one given a value it refuses, are
# separate shared examples: not every resource has such a member.
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

  context 'when an attribute does not exist' do
    let(:resource_attributes) { { winnie_the_pooh: :winnie_the_pooh } }

    it 'contains an error field' do
      expect(response.parsed_body['errors']).not_to be_nil
    end

    it 'contains resource errors in the error field' do
      expect(response.parsed_body['errors'].first).to be_a(Hash)
    end

    it 'points to the failed attribute in the error field' do
      expect(response.parsed_body['errors'].first['source']['pointer']).to eq("/#{class_sym}/winnie_the_pooh")
    end
  end
end

# For an update endpoint whose resource has a member the action will not update.
#
# Expects the following declared:
#     owner                  - the user the resource belongs to
#     resource               - the record under test
#     path                   - the endpoint's path for that record
#     class_sym              - the member the request body wraps the resource in
#     resource_attributes    - a body the action accepts
#     unupdateable_attribute - a member the action will not update
RSpec.shared_examples('a serialisable resource that refuses an unupdateable member') do
  before do
    put(
      path,
      headers: v2_bearer(owner),
      params: { class_sym => resource_attributes },
      as: :json
    )
  end

  context 'when an attribute is not updateable' do
    context 'when only updating that attribute' do
      let(:resource_attributes) { { unupdateable_attribute => :winnie_the_pooh } }

      it 'does not contain a data field' do
          expect(response.parsed_body['data']).to be_nil
      end

      it 'contains an error field' do
          expect(response.parsed_body['errors']).not_to be_nil
      end

      it 'contains resource errors in the error field' do
          expect(response.parsed_body['errors'].first).to be_a(Hash)
      end

      it 'contains validation error code in the error field' do
          expect(response.parsed_body['errors'].first['code']).to eq("param_invalid")
      end

      it 'points to the failed attribute in the error field' do
          expect(response.parsed_body['errors'].first['source']['pointer']).to eq("/#{class_sym}/#{unupdateable_attribute}")
      end
    end

    context 'when updating a valid attribute as well' do
      let(:resource_attributes) do
        attrs = super()
        attrs[unupdateable_attribute] = :winnie_the_pooh

        attrs
      end

      it 'does not contain a data field' do
          expect(response.parsed_body['data']).to be_nil
      end

      it 'contains an error field' do
          expect(response.parsed_body['errors']).not_to be_nil
      end

      it 'contains resource errors in the error field' do
          expect(response.parsed_body['errors'].first).to be_a(Hash)
      end

      it 'contains validation error code in the error field' do
          expect(response.parsed_body['errors'].first['code']).to eq("param_invalid")
      end

      it 'points to the failed attribute in the error field' do
          expect(response.parsed_body['errors'].first['source']['pointer']).to eq("/#{class_sym}/#{unupdateable_attribute}")
      end
    end
  end
end

# For an update endpoint whose resource has a member that refuses a value.
#
# Expects the following declared:
#     owner                  - the user the resource belongs to
#     resource               - the record under test
#     path                   - the endpoint's path for that record
#     class_sym              - the member the request body wraps the resource in
#     resource_attributes    - a body the action accepts
#     strict_attribute       - a member that refuses strict_attribute_value
#     strict_attribute_value - a value it refuses; a list if the member takes one, and the error
#                              then points at the element rather than the member
RSpec.shared_examples('a serialisable resource that refuses an invalid member') do
  # A member holding a list is refused for the element that failed rather than for the member, and
  # the value given carries one bad element, so it is the first.
  let(:strict_attribute_pointer) do
    pointer = "/#{class_sym}/#{strict_attribute}"

    strict_attribute_value.is_a?(Array) ? "#{pointer}/0" : pointer
  end

  before do
    put(
      path,
      headers: v2_bearer(owner),
      params: { class_sym => resource_attributes },
      as: :json
    )
  end

  context 'when an attribute has an invalid value' do
    let(:resource_attributes) do
      attrs = super()
      attrs[strict_attribute] = strict_attribute_value

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
      expect(response.parsed_body['errors'].first['source']['pointer']).to eq(strict_attribute_pointer)
    end
  end
end

# For index endpoints
#
# Expects the following declared:
#     owner      - the user the resource belongs to
#     path       - the endpoint's path
#     class_sym  - the resource's factory, used to create a few of them
#     serialiser - the serialiser the endpoint renders with
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
#     owner    - the user the resource belongs to
#     resource - the record under test
#     path     - the endpoint's path for that record
RSpec.shared_examples('a serialisable resource on delete') do
  before do
    delete(path, headers: v2_bearer(owner), as: :json)
  end

  context 'when the owner of the scenario' do
    it_behaves_like 'a v2 no_content response'
  end
end

# For any action reading a wrapped resource body.
#
# ParamsWrapper would otherwise rebuild an unwrapped body from the model's column names, dropping
# every member that is not a column before the action could refuse it.
#
# Expects the following declared:
#     owner               - the user the resource belongs to
#     path                - the endpoint's path
#     class_sym           - the member the request body wraps the resource in
#     verb                - :post or :put
#     resource_attributes - a body the action accepts, sent here without its wrapper
RSpec.shared_examples('an action that requires the wrapper key') do
  before do
    public_send(verb, path, headers: v2_bearer(owner), params: resource_attributes, as: :json)
  end

  it 'refuses a body sent without its wrapper key' do
    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body.dig('errors', 0, 'code')).to eq('param_missing')
    expect(response.parsed_body.dig('errors', 0, 'source', 'pointer')).to eq("/#{class_sym}")
  end
end

# For an index that answers one page at a time.
#
# A caller reads a page with `page` and `limit`; `limit` is capped rather than refused, so no single
# request can ask for the lot. What the page holds is reported under meta/pagination.
#
# Expects the following declared:
#     owner     - the user the records belong to
#     path      - the endpoint's path
#     class_sym - the member the request body wraps the resource in, and the factory name
RSpec.shared_examples('a paginated collection endpoint') do
  before { create_list(class_sym, 3, user: owner) }

  let(:headers) { v2_bearer(owner, :read) }

  it 'answers a first page, and says how many records there are' do
    get(path, headers: headers, as: :json)

    expect(response.parsed_body['data'].size).to eq(3)
    expect(response.parsed_body.dig('meta', 'pagination'))
      .to eq('page' => 1, 'limit' => 25, 'pages' => 1, 'count' => 3)
  end

  it 'honours a limit, and reports the pages it implies' do
    get("#{path}?limit=2", headers: headers, as: :json)

    expect(response.parsed_body['data'].size).to eq(2)
    expect(response.parsed_body.dig('meta', 'pagination'))
      .to include('page' => 1, 'limit' => 2, 'pages' => 2, 'count' => 3)
  end

  it 'answers the remainder on the next page' do
    get("#{path}?limit=2&page=2", headers: headers, as: :json)

    expect(response.parsed_body['data'].size).to eq(1)
    expect(response.parsed_body.dig('meta', 'pagination')).to include('page' => 2)
  end

  it 'caps a limit above the maximum rather than refusing it' do
    get("#{path}?limit=9999", headers: headers, as: :json)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('meta', 'pagination', 'limit')).to eq(100)
  end

  # A page past the last is not the caller getting something wrong, and an empty page says so
  # without needing an error code of its own.
  it 'answers an empty page past the last, rather than an error' do
    get("#{path}?page=99", headers: headers, as: :json)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to validate_against_the_v2_envelope(:collection)
    expect(response.parsed_body['data']).to be_empty
  end
end
