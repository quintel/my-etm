# frozen_string_literal: true

# Moves saved scenarios and collections, with their engine scenarios, from the default version to a
# stable version while that version is hidden. Records and scenarios keep their ids.
#
# The steps:
#   1. Prepare the folder         DIR on both hosts, with selection.yml on the default version's host
#   2. Take production offline    not for a dry run
#   3. Plan                       stable_move:plan, in my-etm
#   4. Export                     stable_move:export, in the default version's etengine
#   5. Copy the export            export.msgpack.gz to DIR on the stable version's host
#   6. Import                     stable_move:import, in the stable version's etengine
#   7. Commit                     stable_move:commit, in my-etm
#   8. Bring production back online
# To undo step 7: stable_move:revert, in my-etm.
#
# A dry run is steps 1, 3 and 4 with production online: plan and export change nothing.
#
# Every task reads and writes DIR, /stable_move unless given, and refuses when it doesn't exist.
namespace :stable_move do
  stable_dir = lambda do
    dir = Pathname.new(ENV.fetch("DIR", "/stable_move"))
    dir.directory? ? dir : abort("#{dir} doesn't exist. Mount it with -v, or give another DIR")
  end
  id_list = ->(name) { ENV.fetch(name, "").split(",").map(&:strip).reject(&:empty?) }
  stable_log = -> { StableMove::Log.new(stable_dir.call.join("move_log.jsonl")) }
  show = ->(lines) { puts "-" * 72, lines, "-" * 72 }
  stop = ->(error) { abort([ "-" * 72, "Stopped: #{error.message}", "-" * 72 ].join("\n")) }

  # Prints a summary and goes on only when the person running the task types yes. Without a terminal
  # there is no answer, so it stops.
  confirm = lambda do |lines, question|
    show.call(lines)
    print("#{question} Type yes to proceed: ")
    $stdout.flush
    abort("Stopped: nothing was changed") unless $stdin.gets&.strip == "yes"
  end

  desc "Prints what moves to a stable version, and writes it to DIR/plan.json once confirmed. Reads " \
       "only. Takes the datasets and saved scenarios that move from DIR/selection.yml. " \
       "Usage: rails 'stable_move:plan[2027]'"
  task :plan, %i[version] => :environment do |_, args|
    tag = args[:version]
    raise StableMove::Error, "give the version the records move to, like rails 'stable_move:plan[2027]'" if tag.blank?

    target = Version.find_by(tag:)
    raise StableMove::Error, "there is no version #{tag}. Give the one the records move to" unless target

    selection = StableMove::Selection.load(stable_dir.call.join("selection.yml"))
    plan = StableMove::Plan.call(target, **selection)

    confirm.call(StableMove::Plan.summary(plan), "Is this the selection for #{plan['version']}?")

    path = stable_dir.call.join("plan.json")
    path.write(JSON.generate(plan))
    puts "Wrote #{path}"
  rescue StableMove::Error => e
    stop.call(e)
  end

  desc "Moves the records in DIR/plan.json to their stable version, once ETEngine's stable_move:export " \
       "and stable_move:import have copied their scenarios. Prints what it will do and asks to confirm. " \
       "Refuses when the records changed since the plan or DIR/export.json is of another plan. Binds the " \
       "copies, deletes the version's test data and the saved scenarios whose current scenario both " \
       "engines lack, then moves the records. Logs to DIR/move_log.jsonl"
  task commit: :environment do
    plan = JSON.parse(stable_dir.call.join("plan.json").read)
    export = JSON.parse(stable_dir.call.join("export.json").read)

    confirm.call(StableMove::Commit.summary(plan, export), "Move these to #{plan['version']}?")

    version, from = plan.values_at("version", "from_version")
    counts = StableMove::Commit.call(plan, export:, log: stable_log.call)
    labels = {
      "moved" => "moved to #{version}",
      "wiped" => "deleted on #{version} as test data",
      "deleted" => "deleted on #{from}, current session gone",
      "skipped" => "skipped, no longer on #{from}"
    }

    show.call([
      "Records logged to move_log.jsonl: #{counts.values.sum}",
      *labels.filter_map { |status, label| "   - #{counts[status]} #{label}" if counts[status] }
    ])
  rescue StableMove::Error => e
    stop.call(e)
  end

  desc "Points records moved to a stable version back to where they came from, with the scenario ids " \
       "they moved with, per DIR/move_log.jsonl. Prints what it will move back and asks to confirm. " \
       "SAVED_SCENARIOS and COLLECTIONS limit it to those ids. Doesn't bring back what stable_move:commit " \
       "deleted. Usage: rails 'stable_move:revert[2027]'"
  task :revert, %i[version] => :environment do |_, args|
    saved_scenarios = id_list.call("SAVED_SCENARIOS").map(&:to_i).presence
    collections = id_list.call("COLLECTIONS").map(&:to_i).presence

    revert = StableMove::Revert.new(args[:version], log: stable_log.call, saved_scenarios:, collections:)

    confirm.call(revert.summary, "Move these back from #{args[:version]}?")

    result = revert.call
    restored = result["scenario_ids_restored"]

    show.call([
      "Records moved back from #{args[:version]}: #{result['reverted']}",
      "",
      "Saved scenarios that lost their changes on #{args[:version]}: #{restored.size}",
      *StableMove::Error.listing(restored)
    ])
  rescue StableMove::Error => e
    stop.call(e)
  end
end
