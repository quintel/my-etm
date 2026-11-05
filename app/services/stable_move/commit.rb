# frozen_string_literal: true

# Moves the records of a StableMove::Plan to the stable version, once ETEngine's stable_move:import has
# copied their scenarios into that version's engine with the same ids. A record keeps its id,
# scenario ids and users; only its version changes.
#
# Before the move, the copies are bound in the stable engine (those of discarded saved scenarios
# are not), which also tells which scenarios the engine lacks. A saved scenario whose current
# scenario is missing was already broken: it is deleted rather than moved.
#
# In one transaction it then:
# - deletes the records on the stable version that aren't in the plan: the hidden period's test data;
# - deletes the broken saved scenarios;
# - moves the saved scenarios and collections.
#
# Refuses once the version is shown, and while an earlier move to it is in place (revert that first),
# so that it never deletes records users made on the stable version or that moved earlier. Refuses
# too while the plan skips a collection: its moving saved scenarios would leave it behind.
#
# plan - The plan, parsed from JSON.
# log  - The StableMove::Log every record is written to.
#
# Returns a Hash with the number of records per status.
class StableMove::Commit
  extend Dry::Initializer
  include Service

  BIND_SLICE = 500

  param :plan
  option :log
  option :user, default: proc { User.robot }

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

    if (mixed = plan.dig("skipped", "collections")).any?
      raise StableMove::Error,
        "Collections #{mixed.map { |item| item['id'] }.join(', ')} hold saved scenarios that stay. " \
        "Handle them first, then plan again"
    end

    if log.in_place(target.tag).any?
      raise StableMove::Error, "An earlier move to #{target.tag} is in place. Revert it first"
    end

    return if ApiScenario::SetBound.supported?(target)

    raise StableMove::Error, "#{target.tag} has no bound flag in ETEngine"
  end

  # Binds the copies of kept saved scenarios and unbinds those of discarded ones, as MyETM does.
  # Returns the ids the stable engine doesn't have.
  def bind
    discarded, kept = plan["saved_scenarios"].partition { |entry| entry["discarded"] }

    { true => kept, false => discarded }.each_with_object(Set.new) do |(bound, entries), missing|
      entries.flat_map { |entry| entry["scenario_ids"] }.uniq.each_slice(BIND_SLICE) do |ids|
        missing.merge(ApiScenario::SetBound.call!(user, target, ids, bound))
      end
    end
  rescue Faraday::Error => e
    raise StableMove::Error, "ETEngine #{target.tag} could not bind the scenarios: #{e.message}"
  end

  def broken_ids(missing)
    plan["saved_scenarios"].filter_map { |entry| entry["id"] if missing.include?(entry["scenario_ids"].first) }
  end

  def wipe
    [ Collection, SavedScenario ].flat_map do |model|
      planned = plan[model.model_name.plural].map { |entry| entry["id"] }

      model.where(version: target).where.not(id: planned).find_each.map do |record|
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

      raise StableMove::Error, "Collection #{item['id']} would hold saved scenarios on another version"
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
