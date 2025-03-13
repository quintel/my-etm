# rubocop:disable Metrics/BlockLength
namespace :data do
  desc "Import data from Model and Engine dumps with table mapping"
  task import: :environment do
    require "fileutils"
    DataImporter.new.run
  end

  class DataImporter
    TABLE_NAME_MAPPING = {
      "multi_year_charts" => "collections",
      "multi_year_chart_saved_scenarios" => "collection_saved_scenarios",
      "multi_year_chart_scenarios" => "collection_scenarios",
      "tmp_users_for_export" => "users",
      "tmp_oauth_access_grants_for_export" => "oauth_access_grants"
    }.freeze

    COLUMN_NAME_MAPPING = {
      "multi_year_charts" => { "multi_year_chart_id" => "collection_id" },
      "multi_year_chart_saved_scenarios" => { "multi_year_chart_id" => "collection_id" },
      "multi_year_chart_scenarios" => { "multi_year_chart_id" => "collection_id" },
      "saved_scenarios" => { "description" => "tmp_description" }
    }.freeze

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
    ].freeze

    def initialize
      @model_dump = ENV["MODEL_DUMP"]
      @engine_dump = ENV["ENGINE_DUMP"]
    end

    def run
      print_dump_paths
      validate_dump_paths
      check_file_existence(@model_dump, "Model dump")
      check_file_existence(@engine_dump, "Engine dump")
      decompress_dumps
      prepare_sql_files
      reset_database
      load_sql_data(@engine_sql, TABLE_NAME_MAPPING, COLUMN_NAME_MAPPING)
      load_sql_data(@model_sql, TABLE_NAME_MAPPING, COLUMN_NAME_MAPPING)
      cleanup_files([ @model_sql, @engine_sql ])
      puts "Data import completed successfully!"
    end

    private

    def print_dump_paths
      puts "MODEL_DUMP: #{@model_dump}"
      puts "ENGINE_DUMP: #{@engine_dump}"
    end

    def validate_dump_paths
      return unless @model_dump.nil? || @engine_dump.nil?
        puts "Error: Please specify both MODEL_DUMP and ENGINE_DUMP file paths."
        puts <<~MSG
          Example:
            MODEL_DUMP=/path/to/model.sql.xz \\
            ENGINE_DUMP=/path/to/engine.sql.xz \\
            rake data:import
        MSG
        exit(1)
    end

    def check_file_existence(file_path, label)
      if File.exist?(file_path)
        puts "#{label} exists: #{file_path}"
      else
        puts "#{label} does not exist: #{file_path}"
      end
    end

    def decompress_dumps
      decompress_dump(@model_dump)
      decompress_dump(@engine_dump)
    end

    def decompress_dump(dump_file)
      return unless File.exist?(dump_file)
      puts "Decompressing #{dump_file}..."
      `xz -d #{dump_file}`
    end

    def prepare_sql_files
      @model_sql = @model_dump.sub(".xz", "")
      @engine_sql = @engine_dump.sub(".xz", "")
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

    def load_sql_data(sql_file, table_mapping, column_mapping)
      return unless File.exist?(sql_file)
      puts "Loading and mapping #{sql_file}..."
      table_statements = Hash.new { |h, k| h[k] = [] }
      process_sql_file(sql_file, table_statements, table_mapping, column_mapping)
      table_statements
    end

    def process_sql_file(sql_file, table_statements, table_mapping, column_mapping)
      File.read(sql_file).split(/;\s*\n/).each_with_index do |chunk, _i|
        chunk.strip!
        next if chunk.empty?
        chunk = filter_irrelevant_lines(chunk)
        next if chunk.empty?
        process_insert_statements(chunk, table_statements, table_mapping, column_mapping)
      end
    end

    def filter_irrelevant_lines(chunk)
      lines = chunk.split("\n").reject do |line|
        line.strip.start_with?("--", "LOCK TABLES", "UNLOCK TABLES", "/*!") ||
          line.strip.include?("Dumping data for table")
      end
      lines.join("\n").strip
    end

    def process_insert_statements(chunk, table_statements, table_mapping, column_mapping)
      return unless chunk.start_with?("INSERT INTO")
      table_name = extract_table_name(chunk)
      return unless table_name
      mapped_table = table_mapping.fetch(table_name, table_name)
      chunk = map_column_names(chunk, column_mapping[table_name]) if column_mapping.key?(table_name)
      chunk.sub!(/INSERT INTO\s+`?#{table_name}`?/i, "INSERT INTO `#{mapped_table}`")
      table_statements[mapped_table] << chunk
    end

    def extract_table_name(chunk)
      chunk[/INSERT INTO\s+`?([a-zA-Z0-9_]+)`?/i, 1]
    end

    def map_column_names(stmt, column_mapping)
      column_mapping.each do |source_column, destination_column|
        if destination_column.nil?
          stmt.gsub!(/`?#{source_column}`?[^,]*,?/, "")
        else
          stmt.gsub!(/`?#{source_column}`?/, "`#{destination_column}`")
        end
      end
      stmt
    end

    def cleanup_files(files)
      files.each do |file|
        FileUtils.rm(file) if File.exist?(file)
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
