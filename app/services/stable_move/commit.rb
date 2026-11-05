# frozen_string_literal: true

# Moves the records of a StableMove::Plan to the stable version, once ETEngine's stable_move:export
# and stable_move:import have copied their scenarios into that version's engine with the same ids. A
# record keeps its id, scenario ids and users; only its version changes.
#
# Before the move, the copies are bound in the stable engine, discarded saved scenarios' too, which
# also tells which scenarios the engine lacks. A saved scenario whose current scenario the export
# already found missing was broken: it is deleted rather than moved.
#
# In one transaction it then:
# - deletes the records on the stable version that aren't in the plan: the hidden period's test data;
# - deletes the broken saved scenarios;
# - moves the saved scenarios and collections.
#
# Refuses, before it changes anything:
# - once the version is shown;
# - when the export is of another plan;
# - when the records differ from the plan, or the plan would be refused now: it plans again and
#   compares.
# After binding, it refuses when the stable engine lacks scenarios the export found: the import is
# of another export.
#
# plan   - The plan, parsed from JSON.
# export - The report of ETEngine's stable_move:export, parsed from JSON.
# log    - The StableMove::Log every record is written to.
#
# Returns a Hash with the number of records per status.
class StableMove::Commit
  extend Dry::Initializer
  include Service

  BIND_SLICE = 500

  param :plan
  option :export
  option :log
  option :user, default: proc { User.robot }

  # Public: The records of a model on the target version that aren't in the plan.
  def self.test_data(model, target, plan)
    model.where(version: target).where.not(id: plan[model.model_name.plural].map { |entry| entry["id"] })
  end

  # Public: What the commit would do if it ran now, for a person to confirm: the plan's summary, with
  # the saved scenarios it deletes because the export found their current scenario missing.
  def self.summary(plan, export)
    missing = export["missing_scenarios"].to_set
    broken = plan["saved_scenarios"].filter_map { |entry| entry["id"] if missing.include?(entry["scenario_ids"].first) }

    StableMove::Plan.summary(plan, deleted: broken) + [
      "",
      "#{plan['from_version'].upcase_first} cleanup in MyETM (current session gone): #{broken.size}",
      "   - #{broken.size} #{'saved scenario'.pluralize(broken.size)}"
    ]
  end

  def call
    check!

    broken = broken_ids(bind)
    entries = []

    ActiveRecord::Base.transaction do
      entries.concat(wipe)
      entries.concat(delete_broken(broken))
      entries.concat(move(SavedScenario, plan["saved_scenarios"], broken))
      entries.concat(move(Collection, plan["collections"], broken))
      check_collections!(broken)
    end

    log.append(entries)
    entries.map { |entry| entry["status"] }.tally
  end

  private

  def source
    @source ||= Version.find_by!(tag: plan["from_version"])
  end

  def target
    @target ||= Version.find_by!(tag: plan["version"])
  end

  def check!
    raise StableMove::Error, "#{target.tag} is shown: a move only runs while it is hidden" unless target.hidden

    unless export["planned_at"] == plan["planned_at"]
      raise StableMove::Error, "the export is of another plan: export and import again"
    end

    check_unchanged!
  end

  def check_unchanged!
    current = JSON.parse(JSON.generate(
      StableMove::Plan.call(target, datasets: plan["datasets"], handpicked: plan["handpicked"])
    ))

    return if current.except("planned_at") == plan.except("planned_at")

    saved = changed_ids(plan["saved_scenarios"], current["saved_scenarios"])
    collections = changed_ids(plan["collections"], current["collections"])

    if saved.empty? && collections.empty?
      raise StableMove::Error, "the plan changed since it was made, outside its saved scenarios and " \
        "collections: plan, export and import again"
    end

    raise StableMove::Error, [
      "records changed since the plan.",
      "",
      "Saved scenarios changed: #{saved.size}", *StableMove::Error.listing(saved),
      "",
      "Collections changed: #{collections.size}", *StableMove::Error.listing(collections),
      "",
      "Plan, export and import again."
    ].join("\n")
  end

  def changed_ids(planned, current)
    planned = planned.index_by { |entry| entry["id"] }
    current = current.index_by { |entry| entry["id"] }

    (planned.keys | current.keys).reject { |id| planned[id] == current[id] }.sort
  end

  # Binds the copies of every saved scenario, discarded ones too. Returns the ids the stable engine
  # doesn't have.
  def bind
    ids = plan["saved_scenarios"].flat_map { |entry| entry["scenario_ids"] }.uniq

    ids.each_slice(BIND_SLICE).each_with_object(Set.new) do |slice, missing|
      missing.merge(ApiScenario::SetBound.call!(user, target, slice, true))
    end
  rescue Faraday::Error => e
    raise StableMove::Error, "ETEngine #{target.tag} could not bind the scenarios: #{e.message}"
  end

  # The saved scenarios whose current scenario is missing in both engines.
  def broken_ids(missing)
    unexpected = missing - export["missing_scenarios"]

    if unexpected.any?
      raise StableMove::Error, [
        "ETEngine #{target.tag} lacks engine sessions the export found, so the import is of another export.",
        "",
        "Engine sessions missing in #{target.tag}: #{unexpected.size}",
        *StableMove::Error.listing(unexpected.sort),
        "",
        "Export and import again."
      ].join("\n")
    end

    plan["saved_scenarios"].filter_map { |entry| entry["id"] if missing.include?(entry["scenario_ids"].first) }
  end

  def wipe
    [ Collection, SavedScenario ].flat_map do |model|
      self.class.test_data(model, target, plan).find_each.map do |record|
        record.destroy!
        entry(record, "wiped", "test data", from: target, to: nil)
      end
    end
  end

  def delete_broken(ids)
    SavedScenario.where(id: ids, version: source).find_each.map do |saved|
      saved.destroy!
      entry(saved, "deleted", "engine scenario missing", from: source, to: nil, scenario_ids: saved.all_scenario_ids)
    end
  end

  def move(model, planned, broken)
    planned = planned.reject { |item| model == SavedScenario && broken.include?(item["id"]) }
    scope = model.where(id: planned.map { |item| item["id"] }, version: source)
    on_source = scope.pluck(:id).to_set

    scope.update_all(version_id: target.id)

    planned.map do |item|
      reason = item["reason"] || item["kind"]
      ids = item["scenario_ids"]

      if on_source.include?(item["id"])
        record_entry(model, item["id"], "moved", reason, from: source, to: target, scenario_ids: ids)
      else
        record_entry(model, item["id"], "skipped", "not on #{source.tag}", from: source, to: target, scenario_ids: ids)
      end
    end
  end

  # A collection and its saved scenarios must share a version (Collection#validate_scenario_versions).
  def check_collections!(broken)
    plan["collections"].each do |item|
      saved_ids = item["saved_scenario_ids"] - broken
      next if SavedScenario.where(id: saved_ids).where.not(version: target).none?

      raise StableMove::Error, "collection #{item['id']} would hold saved scenarios on another version"
    end
  end

  def entry(record, status, reason, from:, to:, scenario_ids: nil)
    record_entry(record.class, record.id, status, reason, from:, to:, scenario_ids:)
  end

  def record_entry(model, id, status, reason, from:, to:, scenario_ids:)
    {
      "record_type" => model.name,
      "record_id" => id,
      "status" => status,
      "reason" => reason,
      "from_version" => from&.tag,
      "to_version" => to&.tag,
      "scenario_ids" => scenario_ids
    }
  end
end
