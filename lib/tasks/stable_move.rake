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
# The full procedure, with the commands for the servers, is in the stable version runbook.
namespace :stable_move do
  stable_dir = lambda do
    dir = Pathname.new(ENV.fetch("DIR", "/stable_move"))
    dir.directory? ? dir : abort("#{dir} doesn't exist. Mount it with -v, or give another DIR")
  end
  id_list = ->(name) { ENV.fetch(name, "").split(",").map(&:strip).reject(&:empty?) }
  stable_log = -> { StableMove::Log.new(stable_dir.call.join("move_log.jsonl")) }

  desc "Writes what moves to a stable version to DIR/plan.json and prints a summary. Reads only. " \
       "Takes the datasets and saved scenarios that move from DIR/selection.yml. " \
       "Usage: rails 'stable_move:plan[2027]'"
  task :plan, %i[version] => :environment do |_, args|
    selection = StableMove::Selection.load(stable_dir.call.join("selection.yml"))

    plan = StableMove::Plan.call(Version.find_by!(tag: args[:version]), **selection)
    path = stable_dir.call.join("plan.json")
    path.write(JSON.generate(plan))

    puts JSON.pretty_generate(StableMove::Plan.summary(plan).merge("file" => path.to_s))
  rescue StableMove::Error => e
    abort(e.message)
  end

  desc "Moves the records in DIR/plan.json to their stable version, once ETEngine's stable_move:export " \
       "and stable_move:import have copied their scenarios. Refuses when the records changed since the " \
       "plan or DIR/export.json is of another plan. Binds the copies, deletes the version's test data " \
       "and the saved scenarios whose current scenario both engines lack, then moves the records. " \
       "Logs to DIR/move_log.jsonl"
  task commit: :environment do
    plan = JSON.parse(stable_dir.call.join("plan.json").read)
    export = JSON.parse(stable_dir.call.join("export.json").read)

    puts JSON.pretty_generate(StableMove::Commit.call(plan, export:, log: stable_log.call))
  rescue StableMove::Error => e
    abort(e.message)
  end

  desc "Points records moved to a stable version back to where they came from, with the scenario ids " \
       "they moved with, per DIR/move_log.jsonl. SAVED_SCENARIOS and COLLECTIONS limit it to those ids. " \
       "Doesn't bring back what stable_move:commit deleted. Usage: rails 'stable_move:revert[2027]'"
  task :revert, %i[version] => :environment do |_, args|
    saved_scenarios = id_list.call("SAVED_SCENARIOS").map(&:to_i).presence
    collections = id_list.call("COLLECTIONS").map(&:to_i).presence

    puts JSON.pretty_generate(
      StableMove::Revert.call(args[:version], log: stable_log.call, saved_scenarios:, collections:)
    )
  rescue StableMove::Error => e
    abort(e.message)
  end
end
