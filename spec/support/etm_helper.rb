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

  # Mock a Faraday streaming response that uses on_data callback
  #
  # @param http_client [RSpec::Mocks::Double] The mocked HTTP client
  # @param endpoint [String] The API endpoint path
  # @param ndjson_body [String] The NDJSON response body (newline-delimited JSON)
  # @param status [Integer] HTTP status code (default: 200)
  #
  # @example
  #   mock_streaming_response(http_client, '/api/v3/scenarios/export', "#{json1}\n#{json2}\n", 200)
  #
  def mock_streaming_response(http_client, endpoint, ndjson_body, status: 200)
    allow(http_client).to receive(:post).with(endpoint) do |&block|
      # Create actual Ruby objects instead of doubles to properly handle attribute assignment
      request = Struct.new(:headers, :body, :options).new({}, nil, nil)

      # Create options object with attr_accessor for on_data
      options_class = Class.new do
        attr_accessor :on_data
      end
      request.options = options_class.new

      # Yield to the block so the service can configure the request
      # Note: Use `if block` not `if block_given?` since block is a captured parameter
      block.call(request) if block

      # Simulate streaming by calling on_data with chunks
      if request.options.on_data
        # Stream each line incrementally
        ndjson_body.each_line do |line|
          request.options.on_data.call(line, line.bytesize)
        end
      end

      # Return a mock response
      instance_double(Faraday::Response, success?: (status >= 200 && status < 300), status: status, body: '')
    end
  end
end

RSpec.configure do |config|
  config.include EtmHelper
end
