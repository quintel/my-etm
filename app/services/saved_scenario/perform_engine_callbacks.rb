# frozen_string_literal: true

# Performs ETEngine callbacks for a SavedScenario. Every operation is attempted even when an
# earlier one fails.
#
# Supports the following operations:
# - :protect     - Keep the scenario compatible
# - :tag_version - Tag the scenario version
# - :set_privacy - Match the scenario's privacy, which needs the saved_scenario option
#
# Returns a Dry::Monads::Result. A failure carries an [:upstream, messages] pair.
class SavedScenario::PerformEngineCallbacks
  extend Dry::Initializer
  include Service
  include Dry::Monads[:result]

  param :http_client
  param :scenario_id
  option :operations, default: proc { [ :protect, :tag_version ] }
  option :saved_scenario, optional: true

  def call
    failed = operations.map { |op| perform_operation(op) }.reject(&:successful?)
    failed.empty? ? Success(scenario_id) : Failure([ :upstream, messages(failed) ])
  end

  private

  def perform_operation(operation)
    case operation
    when :protect
      ApiScenario::SetCompatibility.keep_compatible(http_client, scenario_id)
    when :tag_version
      ApiScenario::VersionTags::Create.call(http_client, scenario_id, "")
    when :set_privacy
      ApiScenario::UpdatePrivacy.call(http_client, scenario_id, private: saved_scenario.private)
    else
      raise ArgumentError, "Unknown engine callback: #{operation.inspect}"
    end
  end

  # SetCompatibility can fail without a message
  def messages(failed)
    failed.flat_map(&:errors).presence || [ "ETEngine refused the request" ]
  end
end
