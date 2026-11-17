# frozen_string_literal: true

module Api
  module V4
    class ScenarioAccessSerialiser
      def initialize(scenario_access, tag:)
        @scenario_access = scenario_access
        @tag = tag
      end

      def as_json(*)
        scenario_access.levels(tag)
      end

      private

      attr_reader :scenario_access, :tag
    end
  end
end
