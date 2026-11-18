# frozen_string_literal: true

module Api
  module V4
    # Tells nginx whether to relay a call under /api/v4/saved_scenarios/:id/*path to the engine, and
    # where to. nginx passes the original call in the X-Original-URI and X-Original-Method headers
    class RelayController < BaseController
      RELAYED_PATH = %r{\A/api/v4/saved_scenarios/(?<id>\d+)/(?<path>[^?]*)}
      DENIED_SEGMENTS = %w[users bind dump interpolate].freeze

      # Engine's Rack::MethodOverride can turn a POST into a DELETE, so the Session itself is
      # relayed for these methods only
      SESSION_METHODS = %w[GET PUT PATCH].freeze

      NEVER_RELAYED_SCOPES = %w[roles scenarios:bind].freeze

      # The verdict names its real refusal in these, and nginx hands them on to the refusal renderer
      REFUSAL_HEADERS = %w[X-Etm-Refusal-Status X-Etm-Refusal-Code X-Etm-Refusal-Detail].freeze

      skip_before_action :require_user
      skip_authorization_check only: :refusal

      before_action :refuse_unrelayed_path, :resolve_saved_scenario, :reject_discarded_scenario,
        only: :verdict

      # nginx's auth_request asks here with the original call's method
      def verdict
        relay_headers.compact.each { |name, value| response.set_header(name, value) }
        render_no_content
      end

      # nginx's error_page sends a refused verdict here, with the refusal the verdict named
      def refusal
        status, code, detail = REFUSAL_HEADERS.map { |name| request.headers[name] }

        return render_unauthenticated if status == "401"
        return render_not_relayed unless status.to_i.between?(400, 499) && code.present?

        render_error(status: status.to_i, code:, detail:)
      end

      private

      # auth_request passes only 2xx, 401 and 403 through, and turns any other status into a 500
      def render_error(status:, code:, detail:, source: nil)
        return super unless action_name == "verdict"

        status = Rack::Utils.status_code(status)
        REFUSAL_HEADERS.zip([ status.to_s, code, detail ]).each { |name, value| response.set_header(name, value) }

        super(status: status == 401 ? 401 : 403, code:, detail:, source:)
      end

      def render_not_relayed
        render_error(status: :forbidden, code: EtmApi::Errors::Codes::FORBIDDEN, detail: "Not relayed")
      end

      def refuse_unrelayed_path
        render_not_relayed unless original_call && relayable?
      end

      def resolve_saved_scenario
        @saved_scenario = SavedScenario.find(original_call[:id])
        authorize!(:read, @saved_scenario)
      end

      def relayable?
        decoded = Rack::Utils.unescape_path(original_call[:path])
        segments = decoded.split("/").reject(&:empty?)

        return false if decoded.include?("..") || DENIED_SEGMENTS.include?(segments.first.to_s[/\A[^.]*/])

        segments.any? || SESSION_METHODS.include?(original_method)
      end

      def original_call
        return @original_call if defined?(@original_call)

        @original_call = RELAYED_PATH.match(request.headers["X-Original-URI"].to_s)
      end

      def original_method
        request.headers["X-Original-Method"].presence || request.request_method
      end

      def relay_headers
        {
          "X-Engine-Origin" => @saved_scenario.version.engine_url,
          "X-Engine-Path" => "/api/v3/scenarios/#{@saved_scenario.scenario_id}/#{original_call[:path]}",
          "X-Engine-Token" => engine_token,
          "X-Etm-User-Id" => current_user&.id&.to_s,
          "X-Etm-Pat-Id" => current_token&.id&.to_s,
          "X-Etm-Version" => @saved_scenario.version.tag
        }
      end

      def engine_token
        return unless current_user

        MyEtm::Auth.relay_token(current_user, @saved_scenario, level: grant_level, scopes: relayed_scopes)
      end

      # A caller who can read the Scenario without holding a role on it, such as a public one, reads
      def grant_level
        @saved_scenario.access_level_for(current_user) || ScenarioAccess::READ
      end

      def relayed_scopes
        (current_token.scopes.to_a - NEVER_RELAYED_SCOPES).join(" ")
      end
    end
  end
end
