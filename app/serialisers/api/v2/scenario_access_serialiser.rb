# frozen_string_literal: true

module Api
  module V2
    class ScenarioAccessSerialiser
      def initialize(scenario_access)
        @scenario_access = scenario_access
      end

      def as_json(*)
        scenario_access.as_claim
      end

      private

      attr_reader :scenario_access
    end
  end
end
