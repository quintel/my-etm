# frozen_string_literal: true

# Works out what moves from the default version to a stable version. Reads only. The result is the
# input of ETEngine's stable_move:export and of StableMove::Commit.
#
# What moves:
# - every saved scenario on the default version in one of the datasets, and the handpicked ones,
#   discarded or not, with their whole history;
# - every collection whose saved scenarios all move;
# - every collection in one of the datasets without saved scenarios. These hold scenarios
#   interpolated from a saved scenario that nothing records any more.
#
# Refuses while a collection holds saved scenarios that move and ones that stay, and lists them: a
# collection and its saved scenarios must share a version, so they are handled by hand first.
#
# Refuses unless the target version is hidden: the move replaces every scenario in that version's
# engine and deletes the records on it that aren't in the plan.
#
# target     - The Version the records move to.
# datasets   - Area codes whose saved scenarios move.
# handpicked - Ids of other saved scenarios that move.
#
# Returns a Hash that serialises to JSON as it is.
class StableMove::Plan
  extend Dry::Initializer
  include Service

  param :target
  option :datasets
  option :handpicked, default: proc { [] }

  def call
    raise StableMove::Error, "#{target.tag} is the default version" if target == source
    raise StableMove::Error, "#{target.tag} is shown: a move only runs while it is hidden" unless target.hidden

    check_collections!

    {
      "version" => target.tag,
      "from_version" => source.tag,
      "planned_at" => Time.current.utc.iso8601,
      "datasets" => datasets,
      "handpicked" => handpicked,
      "saved_scenarios" => saved_scenarios.map { |saved| saved_scenario_entry(saved) },
      "collections" => collections.map { |collection| collection_entry(collection) },
      "skipped" => { "handpicked" => skipped_handpicked },
      "engine" => engine
    }
  end

  # Public: Counts for a person to check before the move, with the records on the target version
  # that StableMove::Commit would delete as test data if it ran now.
  def self.summary(plan)
    saved = plan["saved_scenarios"]
    target = Version.find_by!(tag: plan["version"])

    {
      "version" => plan["version"],
      "saved_scenarios" => saved.group_by { |entry| entry["reason"] }.transform_values do |entries|
        { "total" => entries.size, "discarded" => entries.count { |entry| entry["discarded"] } }
      end,
      "collections" => plan["collections"].group_by { |entry| entry["kind"] }.transform_values(&:size),
      "skipped" => plan["skipped"],
      "engine_scenarios" => plan.dig("engine", "scenario_ids").size,
      "test_data_deleted_at_commit" => [ SavedScenario, Collection ].to_h do |model|
        [ model.model_name.plural, StableMove::Commit.test_data(model, target, plan).count ]
      end
    }
  end

  private

  def source
    @source ||= Version.default
  end

  def saved_scenarios
    @saved_scenarios ||= SavedScenario
      .where(version: source, area_code: datasets)
      .or(SavedScenario.where(version: source, id: handpicked))
      .order(:id)
      .to_a
  end

  def saved_scenario_ids
    @saved_scenario_ids ||= saved_scenarios.to_set(&:id)
  end

  def saved_scenario_entry(saved)
    {
      "id" => saved.id,
      "reason" => datasets.include?(saved.area_code) ? "dataset:#{saved.area_code}" : "handpicked",
      "area_code" => saved.area_code,
      "discarded" => saved.discarded?,
      "scenario_ids" => saved.all_scenario_ids
    }
  end

  # Collections holding a moving saved scenario, and those in a dataset without saved scenarios.
  def candidate_collections
    @candidate_collections ||= begin
      linked = CollectionSavedScenario.where(saved_scenario_id: saved_scenario_ids.to_a).pluck(:collection_id)
      direct_only = Collection.where(area_code: datasets).where.missing(:collection_saved_scenarios).pluck(:id)

      Collection.where(version: source, id: linked + direct_only)
        .includes(:collection_saved_scenarios, :scenarios)
        .order(:id)
        .to_a
    end
  end

  def collections
    candidate_collections.select { |collection| staying_ids(collection).empty? }
  end

  def check_collections!
    mixed = candidate_collections.filter_map do |collection|
      staying = staying_ids(collection)
      "#{collection.id} (staying: #{staying.join(', ')})" if staying.any?
    end

    return if mixed.empty?

    raise StableMove::Error,
      "Collections #{mixed.join(', ')} hold saved scenarios that move and ones that stay. " \
      "Handle them first, then plan again"
  end

  def staying_ids(collection)
    collection.collection_saved_scenarios.map(&:saved_scenario_id).reject { |id| saved_scenario_ids.include?(id) }
  end

  def collection_entry(collection)
    saved_ids = collection.collection_saved_scenarios.map(&:saved_scenario_id)

    {
      "id" => collection.id,
      "kind" => collection_kind(collection, saved_ids),
      "area_code" => collection.area_code,
      "discarded" => collection.discarded?,
      "saved_scenario_ids" => saved_ids,
      "scenario_ids" => collection.scenarios.map(&:scenario_id)
    }
  end

  def collection_kind(collection, saved_ids)
    if saved_ids.empty?
      "direct_only"
    elsif collection.interpolated? && collection.scenarios.any?
      "transition_path"
    else
      "saved_scenarios"
    end
  end

  def skipped_handpicked
    found = SavedScenario.where(id: handpicked).includes(:version).index_by(&:id)

    handpicked.filter_map do |id|
      if (saved = found[id]).nil?
        { "id" => id, "reason" => "not found" }
      elsif saved.version != source
        { "id" => id, "reason" => "on #{saved.version&.tag || 'no version'}" }
      end
    end
  end

  # What ETEngine needs: the scenarios to copy, which of them to protect, and MyETM's area code for
  # each to compare.
  def engine
    direct = collections.flat_map { |collection| collection.scenarios.map { |s| [ s.scenario_id, collection ] } }

    {
      "scenario_ids" => (saved_scenarios.flat_map(&:all_scenario_ids) + direct.map(&:first)).uniq.sort,
      "protect" => (saved_scenarios.select(&:kept?).map(&:scenario_id) + direct.map(&:first)).uniq.sort,
      "area_codes" => direct.to_h { |id, collection| [ id.to_s, collection.area_code ] }
        .merge(saved_scenarios.to_h { |saved| [ saved.scenario_id.to_s, saved.area_code ] })
    }
  end
end
