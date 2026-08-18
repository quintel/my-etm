# frozen_string_literal: true

# Shared access tests for API::V2 endpoints.
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

RSpec.shared_examples('a read-protected resource') do
  describe 'as a signed-out caller' do
    it 'is hidden, not forbidden, because a 403 would confirm it exists' do
      get(path, as: :json)

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body.dig('errors', 0, 'code')).to eq('not_found')
    end
  end

  describe 'as the owner' do
    it 'is readable with the read scope' do
      get(path, headers: v2_bearer(owner, :read), as: :json)

      expect(response).to have_http_status(:ok)
    end

    it 'is hidden without the read scope' do
      get(path, headers: v2_bearer(owner, :public), as: :json)

      expect(response).to have_http_status(:not_found)
    end

    it 'is hidden once the token is revoked' do
      headers = v2_bearer(owner, :read)
      revoke_v2_bearer(headers)

      get(path, headers: headers, as: :json)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'as a stranger' do
    let(:stranger) { create(:user) }

    it 'is hidden even with the read scope' do
      get(path, headers: v2_bearer(stranger, :read), as: :json)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'as an admin' do
    let(:admin) { create(:user, admin: true) }

    it 'is readable with the read scope' do
      get(path, headers: v2_bearer(admin, :read), as: :json)

      expect(response).to have_http_status(:ok)
    end

    it 'is still hidden without the read scope' do
      get(path, headers: v2_bearer(admin, :public), as: :json)

      expect(response).to have_http_status(:not_found)
    end
  end
end

# Requires `body` in addition to the read group's lets.
RSpec.shared_examples('a write-protected resource') do
  describe 'as a signed-out caller' do
    it 'is hidden' do
      put(path, params: body, headers: {}, as: :json)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'as the owner' do
    it 'is writable with the write scope' do
      put(path, params: body, headers: v2_bearer(owner, :write), as: :json)

      expect(response).not_to have_http_status(:not_found)
      expect(response).not_to have_http_status(:forbidden)
    end

    it 'is refused, not hidden, with only the read scope' do
      put(path, params: body, headers: v2_bearer(owner, :read), as: :json)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig('errors', 0, 'code')).to eq('forbidden')
    end
  end

  describe 'as a stranger' do
    let(:stranger) { create(:user) }

    it 'is hidden even with the write scope' do
      put(path, params: body, headers: v2_bearer(stranger, :write), as: :json)

      expect(response).to have_http_status(:not_found)
    end
  end
end

RSpec.shared_examples('a delete-protected resource') do
  let(:delete_path) { path }

  describe 'as a signed-out caller' do
    it 'is hidden' do
      delete(delete_path, as: :json)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'as the owner' do
    it 'is refused, not hidden, with only the write scope' do
      delete(delete_path, headers: v2_bearer(owner, :write), as: :json)

      expect(response).to have_http_status(:forbidden)
    end

    it 'is permitted with the delete scope' do
      delete(delete_path, headers: v2_bearer(owner, :delete), as: :json)

      expect(response).not_to have_http_status(:not_found)
      expect(response).not_to have_http_status(:forbidden)
    end
  end
end

# For endpoints that list the caller's own resources. Requires `let(:path)`.
RSpec.shared_examples('a caller-scoped collection endpoint') do
  it 'answers 401 to a signed-out caller, because nothing is being hidden' do
    get(path, as: :json)

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body.dig('errors', 0, 'code')).to eq('unauthenticated')
  end

  it 'names the authentication scheme on a 401' do
    get(path, as: :json)

    expect(response.headers['WWW-Authenticate']).to eq('Bearer realm="api"')
  end

  it 'is reachable with the read scope' do
    get(path, headers: v2_bearer(owner, :read), as: :json)

    expect(response).to have_http_status(:ok)
  end

  it 'is unreachable once the token is revoked' do
    headers = v2_bearer(owner, :read)
    revoke_v2_bearer(headers)

    get(path, headers: headers, as: :json)

    expect(response).to have_http_status(:unauthorized)
  end
end
