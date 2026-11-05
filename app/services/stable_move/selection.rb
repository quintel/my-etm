# frozen_string_literal: true

# What a stable move takes, read from a YAML file:
#
#   datasets:          # area codes whose saved scenarios move; may be empty
#     - nl
#   saved_scenarios:   # ids of other saved scenarios that move
#     - 1234           # comments say why, e.g. who asked for it
#
# Returns a Hash with the datasets and handpicked ids, as StableMove::Plan takes them.
class StableMove::Selection
  KEYS = %w[datasets saved_scenarios].freeze

  def self.load(path)
    raise StableMove::Error, "#{path} is missing" unless File.exist?(path)

    data = YAML.safe_load_file(path) || {}
    raise StableMove::Error, "#{path} must hold #{KEYS.join(' and ')}" unless data.is_a?(Hash)

    if (unknown = data.keys - KEYS).any?
      raise StableMove::Error, "#{path} holds unknown keys: #{unknown.join(', ')}"
    end

    datasets = Array(data["datasets"]).map(&:to_s)
    handpicked = Array(data["saved_scenarios"])

    if (invalid = handpicked.reject { |id| id.is_a?(Integer) }).any?
      raise StableMove::Error, "#{path} holds saved scenario ids that aren't numbers: #{invalid.join(', ')}"
    end

    if datasets.empty? && handpicked.empty?
      raise StableMove::Error, "#{path} holds no datasets and no saved scenarios"
    end

    { datasets: datasets.uniq, handpicked: handpicked.uniq }
  rescue Psych::SyntaxError => e
    raise StableMove::Error, "#{path} is not valid YAML: #{e.message}"
  end
end
