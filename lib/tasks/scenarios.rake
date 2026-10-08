namespace :scenarios do
  desc "Bind every undiscarded saved scenario's Sessions on a Version in ETEngine. To be used once only before " \
       "retiring scenario_users completely. Usage: rails 'scenarios:bind[2025.01,you@email.com]'"
  task :bind, %i[version email] => :environment do |_, args|
    version = Version.find_by!(tag: args[:version])
    user = User.find_by!(email: args[:email])
    abort "#{version.tag} has no bound flag in ETEngine" unless ApiScenario::SetBound.supported?(version)

    sessions = SavedScenario.kept.where(version:).select(:id, :scenario_id, :scenario_id_history)
      .find_each.flat_map { |ss| ss.all_scenario_ids.uniq.map { |id| [ id, ss.id ] } }

    rows = sessions.each_slice(500).flat_map do |batch|
      missing = ApiScenario::SetBound.call!(user, version, batch.map(&:first), true)
      batch.select { |id, _| missing.include?(id) }.map { |id, ss_id| "#{ss_id},#{id},missing," }
    rescue Faraday::Error => e
      batch.map { |id, ss_id| "#{ss_id},#{id},failed,#{e.response_status || e.class.name}" }
    end

    path = Rails.root.join("tmp/unbound_#{version.tag}_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv")
    path.write([ "saved_scenario_id,session_id,reason,error", *rows ].join("\n") + "\n")
    puts "#{rows.size} Sessions could not be bound. They are listed in #{path}"
  end
end
