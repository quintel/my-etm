
namespace :data do
  desc "Import and transform data from Model and Engine dumps"
  task import: :environment do
    require 'fileutils'

    # Paths to dump files
    backup_dir = "ready"
    model_dump = "#{backup_dir}/model-#{Date.today}.sql.xz"
    engine_dump = "#{backup_dir}/engine-#{Date.today}.sql.xz"

    # Decompress dump files
    decompress_dump(model_dump)
    decompress_dump(engine_dump)

    model_sql = model_dump.sub('.xz', '')
    engine_sql = engine_dump.sub('.xz', '')

    # Load data into temporary tables
    load_sql_to_temp(model_sql)
    load_sql_to_temp(engine_sql)

    # Begin transforming and inserting data
    import_users
    import_saved_scenarios
    import_featured_scenarios

    # Clean up decompressed files
    cleanup_files([model_sql, engine_sql])

    puts "Data import completed successfully!"
  end

  def decompress_dump(dump_file)
    return unless File.exist?(dump_file)

    puts "Decompressing #{dump_file}..."
    `xz -d #{dump_file}`
  end

  def load_sql_to_temp(sql_file)
    return unless File.exist?(sql_file)

    puts "Loading #{sql_file} into temporary database..."
    ActiveRecord::Base.connection.execute(File.read(sql_file))
  end

  def cleanup_files(files)
    files.each do |file|
      FileUtils.rm(file) if File.exist?(file)
    end
  end

  def import_users
    puts "Importing users..."
    temp_users = ActiveRecord::Base.connection.execute("SELECT * FROM users;")

    temp_users.each do |temp_user|
      # Transform user data
      user_data = {
        email: temp_user['email'],
        encrypted_password: temp_user['encrypted_password'],
        name: temp_user['name'] || "Unnamed User",
        admin: temp_user['admin'] || false,
        private_scenarios: temp_user['private_scenarios'] || false,
        confirmed_at: temp_user['confirmed_at']
      }

      # Create user in target database
      User.create!(user_data)
    end
  end

  def import_saved_scenarios
    puts "Importing saved scenarios..."
    temp_scenarios = ActiveRecord::Base.connection.execute("SELECT * FROM saved_scenarios;")

    temp_scenarios.each do |temp_scenario|
      # Transform scenario data
      scenario_data = {
        scenario_id: temp_scenario['scenario_id'],
        title: temp_scenario['title'],
        area_code: temp_scenario['area_code'],
        end_year: temp_scenario['end_year'],
        private: temp_scenario['private'] || false
      }

      # Create scenario in target database
      SavedScenario.create!(scenario_data)
    end
  end

  def import_featured_scenarios
    puts "Importing featured scenarios..."
    temp_featured = ActiveRecord::Base.connection.execute("SELECT * FROM featured_scenarios;")

    temp_featured.each do |temp|
      # Transform featured scenario data
      featured_data = {
        saved_scenario_id: temp['saved_scenario_id'],
        owner_id: temp['owner_id'],
        group: temp['group'],
        title_en: temp['title_en'],
        title_nl: temp['title_nl']
      }

      # Create featured scenario in target database
      FeaturedScenario.create!(featured_data)
    end
  end
end
