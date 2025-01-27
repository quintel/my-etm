namespace :data do
  desc "Import data from Model and Engine dumps with table mapping"
  task import: :environment do
    require 'fileutils'

    # Get the paths to the dumps from task arguments
    model_dump = File.expand_path(ENV['MODEL_DUMP'])
    engine_dump = File.expand_path(ENV['ENGINE_DUMP'])

    puts "MODEL_DUMP: #{model_dump}"
    puts "ENGINE_DUMP: #{engine_dump}"

    if model_dump.nil? || engine_dump.nil?
      puts "Error: Please specify both MODEL_DUMP and ENGINE_DUMP file paths."
      puts "Example: MODEL_DUMP=/path/to/model.sql.xz ENGINE_DUMP=/path/to/engine.sql.xz rake data:import"
      exit 1
    end

    if File.exist?(model_dump)
      puts "Model dump exists: #{model_dump}"
    else
      puts "Model dump does not exist: #{model_dump}"
    end

    if File.exist?(engine_dump)
      puts "Engine dump exists: #{engine_dump}"
    else
      puts "Engine dump does not exist: #{engine_dump}"
    end

    # unless File.exist?(model_dump) && File.exist?(engine_dump)
    #   puts "Error: One or both specified dump files do not exist."
    #   exit 1
    # end

    # Map source tables to destination tables if their names differ
    TABLE_NAME_MAPPING = {
      "multi_year_charts" => "collections",
      "multi_year_chart_saved_scenarios" => "collection_saved_scenarios",
      "multi_year_chart_scenarios" => "collection_scenarios",
      "tmp_users_for_export" => "users",
      "tmp_oauth_access_grants_for_export" => "oauth_access_grants"
    }

    # Map source columns to destination columns for specific tables
    COLUMN_NAME_MAPPING = {
      "multi_year_charts" => { "multi_year_chart_id" => "collection_id" },
      "multi_year_chart_saved_scenarios" => { "multi_year_chart_id" => "collection_id" },
      "multi_year_chart_scenarios" => { "multi_year_chart_id" => "collection_id" },
      "saved_scenarios" => { "description" => "tmp_description" }
    }

    TABLE_INSERT_ORDER = [
      "users",
      "oauth_applications",
      "oauth_access_tokens",
      "oauth_openid_requests",
      "staff_applications",
      "oauth_access_grants",
      "saved_scenarios",
      "saved_scenario_users",
      "collections",
      "collection_saved_scenarios",
      "collection_scenarios"
    ]

    # Decompress the dumps
    decompress_dump(model_dump)
    decompress_dump(engine_dump)

    model_sql = model_dump.sub('.xz', '')
    engine_sql = engine_dump.sub('.xz', '')

    # Reset database: drop, create, and migrate to ensure schema matches our destination application
    reset_database

    # Load Engine data with table and column name mapping
    load_and_map_sql_data(engine_sql, TABLE_NAME_MAPPING, COLUMN_NAME_MAPPING)

    # Load Model data with table and column name mapping
    load_and_map_sql_data(model_sql, TABLE_NAME_MAPPING, COLUMN_NAME_MAPPING)

    # Cleanup decompressed files
    cleanup_files([model_sql, engine_sql])

    puts "Data import completed successfully!"
  end

  def decompress_dump(dump_file)
    return unless File.exist?(dump_file)
    puts "Decompressing #{dump_file}..."
    `xz -d #{dump_file}`
  end

  def load_and_map_sql_data(sql_file, table_mapping, column_mapping)
    return unless File.exist?(sql_file)

    puts "Loading and mapping #{sql_file}..."

    # Hash to collect statements for each table
    table_statements = Hash.new { |h, k| h[k] = [] }

    # Read and split statements
    File.read(sql_file).split(/;\s*\n/).each_with_index do |chunk, i|
      chunk.strip!
      next if chunk.empty?

      # Pre-process each chunk by splitting into lines for granular filtering
      lines = chunk.split("\n").reject do |line|
        # Skip irrelevant comment or directive lines
        line.strip.start_with?("--") ||
        line.strip.start_with?("LOCK TABLES") ||
        line.strip.start_with?("UNLOCK TABLES") ||
        line.strip.start_with?("/*!") ||
        line.strip.include?("Dumping data for table")
      end

      # Reassemble the chunk after filtering lines
      chunk = lines.join("\n").strip
      next if chunk.empty?

      # Process INSERT INTO statements
      if chunk.start_with?("INSERT INTO")
        table_name = chunk[/INSERT INTO\s+`?([a-zA-Z0-9_]+)`?/i, 1]
        if table_name
          mapped_table = table_mapping.fetch(table_name, table_name)

          # Map column names if applicable
          if column_mapping.key?(table_name)
            chunk = map_column_names(chunk, column_mapping[table_name])
          end

          # Replace the table name in the statement
          chunk.sub!(/INSERT INTO\s+`?#{table_name}`?/i, "INSERT INTO `#{mapped_table}`")
          table_statements[mapped_table] << chunk
        end
      end
    end

    # Process statements in dependency order
    TABLE_INSERT_ORDER.each do |table_name|
      next unless table_statements.key?(table_name)

      puts "Processing table: #{table_name}"
      table_statements[table_name].each_with_index do |statement, index|
        begin
          ActiveRecord::Base.connection.execute(statement)
        rescue ActiveRecord::InvalidForeignKey => e
          puts "Skipping invalid foreign key reference: #{e.message}" # This only impacts a couple of collection saved scenarios on Beta, we should see how much it impacts on pro
        rescue StandardError => e
          puts "Error on statement for table #{table_name}, index #{index + 1}: #{e.message}"
          raise
        end
      end
    end
  end

  def map_column_names(stmt, column_mapping)
    column_mapping.each do |source_column, destination_column|
      if destination_column.nil?
        # Remove any occurrences of the source column from the INSERT statement
        stmt.gsub!(/`?#{source_column}`?[^,]*,?/, '')
      else
        stmt.gsub!(/`?#{source_column}`?/, "`#{destination_column}`")
      end
    end
    stmt
  end

  def load_sql_file(sql_file)
    return unless File.exist?(sql_file)

    puts "Loading #{sql_file}..."
    File.read(sql_file).split(/;\s*\n/).each_with_index do |stmt, i|
      stmt.strip!
      next if stmt.empty?

      begin
        ActiveRecord::Base.connection.execute(stmt)
      rescue StandardError => e
        puts "Error on statement #{i + 1}: #{e.message}"
        raise
      end
    end
  end

  def reset_database
    puts "Dropping and recreating the database..."
    db_config = ActiveRecord::Base.connection_db_config.configuration_hash
    db_name = db_config[:database]

    ActiveRecord::Base.connection.execute("DROP DATABASE IF EXISTS `#{db_name}`;")
    ActiveRecord::Base.connection.execute("CREATE DATABASE `#{db_name}`;")

    ActiveRecord::Base.establish_connection(db_config)

    puts "Running migrations..."
    Rake::Task["db:migrate"].invoke
    puts "Database reset and migrated."
  end

  def cleanup_files(files)
    files.each do |file|
      FileUtils.rm(file) if File.exist?(file)
    end
  end
end
