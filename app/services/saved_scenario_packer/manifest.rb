# frozen_string_literal: true

# Builds a manifest.json file for a saved scenario dump.
# The manifest contains metadata about the saved scenarios and instructions for loading.
class SavedScenarioPacker::Manifest
  extend Dry::Initializer

  param :saved_scenarios
  param :source_environment, default: -> { Rails.env.to_s }

  # Builds the manifest as a hash
  #
  # Returns a Hash suitable for JSON serialization
  def as_json
    {
      version: '1.0',
      source_environment: source_environment,
      created_at: Time.current.iso8601,
      etm_version: version_tag,
      saved_scenarios: saved_scenarios_data
    }
  end

  # Converts the manifest to a JSON string
  #
  # Returns a String
  def to_json
    JSON.pretty_generate(as_json)
  end

  private

  def version_tag
    # Get the most common version, or default if mixed
    versions = saved_scenarios.map { |ss| ss.version&.tag }.compact
    return 'unknown' if versions.empty?

    versions.group_by(&:itself).values.max_by(&:size).first
  end

  def saved_scenarios_data
    saved_scenarios.map do |saved_scenario|
      owner_ssu = saved_scenario.owners.first
      collaborator_ssus = saved_scenario.collaborators
      viewer_ssus = saved_scenario.viewers

      {
        saved_scenario_id: saved_scenario.id,
        scenario_id: saved_scenario.scenario_id,
        scenario_id_history: saved_scenario.scenario_id_history || [],
        title: saved_scenario.title,
        description: saved_scenario.description.to_plain_text,
        area_code: saved_scenario.area_code,
        end_year: saved_scenario.end_year,
        private: saved_scenario.private,
        version_tag: saved_scenario.version&.tag,
        owner: user_data(owner_ssu&.user, 'owner'),
        collaborators: collaborator_ssus.map { |ssu| user_data(ssu.user, 'collaborator') }.compact,
        viewers: viewer_ssus.map { |ssu| user_data(ssu.user, 'viewer') }.compact,
        created_at: saved_scenario.created_at.iso8601,
        updated_at: saved_scenario.updated_at.iso8601
      }
    end
  end

  def user_data(user, role = 'owner')
    return nil unless user

    {
      email: user.email,
      name: user.name,
      role: role
    }
  end
end
