module Api
  module V1
    class VersionsController < BaseController

      def index
        versions = Version.all
        base_url = request.base_url

        version_data = versions.map do |version|
          {
            version: version,
            url: version_url(version, base_url)
          }
        end

        render json: { versions: version_data }, status: :ok
      end

      private

      # Generates a version URL given a version name and the base URL
      def version_url(version, base_url)
        "https://#{version}.#{base_url}"
      end


    end
  end
end
