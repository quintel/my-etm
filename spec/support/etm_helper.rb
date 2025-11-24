# frozen_string_literal: true

require 'zstd-ruby'

module EtmHelper
  # Helper method to read and parse an ETM file
  def extract_from_etm(file_path)
    compressed_data = File.binread(file_path)
    json_data = Zstd.decompress(compressed_data)
    JSON.parse(json_data, symbolize_names: true)
  end

  # Helper method to create an ETM file for testing
  # data should be a hash that will be converted to JSON
  def create_etm_file(path, data)
    json_data = JSON.pretty_generate(data)
    compressed_data = Zstd.compress(json_data, level: 3)
    File.binwrite(path, compressed_data)
  end
end

RSpec.configure do |config|
  config.include EtmHelper
end
