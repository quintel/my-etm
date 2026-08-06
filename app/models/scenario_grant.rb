# frozen_string_literal: true

# A signed statement, carried in an identity token, that its bearer may read or write one scenario.
#
# Owns the shape of the `scenario_access` claim. ETEngine re-implements the reading half, so any
# change here needs a change there; spec/requests/token_contract_spec.rb pins the shape both sides
# verify against.
#
# `scenario_id` is ETEngine's own id for the scenario, so it authorises without asking MyETM to
# resolve anything.
class ScenarioGrant
  READ = "read"
  WRITE = "write"
  CLAIM = "scenario_access"

  attr_reader :scenario_id, :level

  def initialize(scenario_id:, level:)
    @scenario_id = scenario_id.to_i
    @level = level.to_s == WRITE ? WRITE : READ
  end

  def self.for_role(scenario_id:, writable:)
    new(scenario_id: scenario_id, level: writable ? WRITE : READ)
  end

  def write?
    level == WRITE
  end

  def as_claim
    { "scenario_id" => scenario_id, "level" => level }
  end
end
