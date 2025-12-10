# frozen_string_literal: true

# Performs ETEngine callbacks for a SavedScenario.
#
# Supports the following operations:
# - :protect     - Keep the scenario compatible
# - :set_roles   - Set scenario roles to preset
# - :tag_version - Tag the scenario version
# - :unprotect   - Remove protection from scenario
#
# Returns a ServiceResult.
class SavedScenario::PerformEngineCallbacks
  extend Dry::Initializer
  include Service

  param :http_client
  param :scenario_id
  option :operations, default: proc { [ :protect, :set_roles, :tag_version ] }

  def call
    operations.each { |op| perform_operation(op) }
    ServiceResult.success
  end

  private

  def perform_operation(operation)
    case operation
    when :protect
      ApiScenario::SetCompatibility.keep_compatible(http_client, scenario_id)
    when :set_roles
      ApiScenario::SetRoles.to_preset(http_client, scenario_id)
    when :tag_version
      ApiScenario::VersionTags::Create.call(http_client, scenario_id, "")
    when :unprotect
      ApiScenario::SetCompatibility.unprotect(http_client, scenario_id)
    end
  end
end
