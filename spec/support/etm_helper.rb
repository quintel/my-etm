# frozen_string_literal: true

require 'zstd-ruby'
require 'rubygems/package'
require 'stringio'

module EtmHelper
  # Helper method to read and extract files from an ETM archive
  def extract_from_etm(etm_path)
    compressed_data = File.binread(etm_path)
    tar_data = Zstd.decompress(compressed_data)

    files = {}
    tar_io = StringIO.new(tar_data)

    Gem::Package::TarReader.new(tar_io) do |tar|
      tar.each do |entry|
        files[entry.full_name] = entry.read
      end
    end

    files
  end

  # Helper method to create an ETM file for testing
  def create_etm_file(path, files)
    tar_io = StringIO.new

    Gem::Package::TarWriter.new(tar_io) do |tar|
      files.each do |filename, content|
        tar.add_file_simple(filename, 0644, content.bytesize) do |io|
          io.write(content)
        end
      end
    end

    compressed_data = Zstd.compress(tar_io.string, level: 3)
    File.binwrite(path, compressed_data)
  end
end

RSpec.configure do |config|
  config.include EtmHelper
end
