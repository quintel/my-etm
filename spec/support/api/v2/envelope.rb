# frozen_string_literal: true

# The closed set of Api::V2 response kinds, in plain Ruby: exactly what the base controller's helpers
# are allowed to emit. Read top to bottom, this file *is* the response contract, so keep it small
# enough to stay readable without a schema language.
#
# `data` and `errors` are mutually exclusive because every kind names its own complete key set, and
# no kind names both.
module ApiV2Envelope
  KINDS = %i[resource collection batch ok error].freeze
  ITEM_CODES = %w[not_found forbidden validation_failed internal_error].freeze

  class << self
    # The reasons `body` is not a valid `kind`. Empty means it is.
    def violations(body, kind)
      return [ "#{kind.inspect} is not a v2 response kind (#{KINDS.join(', ')})" ] unless
        KINDS.include?(kind)
      return [ "expected a JSON object, got #{body.class}" ] unless body.is_a?(Hash)

      send("#{kind}_violations", body)
    end

    private

    def resource_violations(body)
      keys(body, %w[data meta]) + object(body["data"], "data") + object(body["meta"], "meta")
    end

    def collection_violations(body)
      keys(body, %w[data meta]) + object(body["meta"], "meta") +
        array(body["data"], "data") { |item, at| object(item, at) }
    end

    def ok_violations(body)
      resource_violations(body) +
        (body.dig("data", "status") == "ok" ? [] : [ "data/status must be \"ok\"" ])
    end

    def batch_violations(body)
      keys(body, %w[data meta]) + batch_meta_violations(body["meta"]) +
        array(body["data"], "data") { |item, at| batch_item_violations(item, at) }
    end

    def error_violations(body)
      keys(body, %w[errors]) +
        array(body["errors"], "errors", min: 1) { |item, at| error_object_violations(item, at) }
    end

    def batch_meta_violations(meta)
      return [ "meta must carry a batch object" ] unless meta.is_a?(Hash) && meta["batch"].is_a?(Hash)

      batch = meta["batch"]
      keys(batch, %w[succeeded failed total], at: "meta/batch") +
        %w[succeeded failed total].flat_map { |key| counter(batch[key], "meta/batch/#{key}") }
    end

    def batch_item_violations(item, at)
      return object(item, at) unless item.is_a?(Hash)

      case item["status"]
      when "ok"    then [] # An ok item carries its resource's own fields, checked by its serialiser.
      when "error" then batch_item_error_violations(item, at)
      else [ "#{at}/status must be \"ok\" or \"error\"" ]
      end
    end

    def batch_item_error_violations(item, at)
      keys(item, %w[status code detail source], at: at) +
        enumerated(item["code"], ITEM_CODES, "#{at}/code") +
        string(item["detail"], "#{at}/detail") +
        pointer_violations(item["source"], "#{at}/source", required: true)
    end

    def error_object_violations(item, at)
      return object(item, at) unless item.is_a?(Hash)

      keys(item, %w[status code detail], optional: %w[source], at: at) +
        integer(item["status"], "#{at}/status") +
        string(item["code"], "#{at}/code") +
        string(item["detail"], "#{at}/detail") +
        pointer_violations(item["source"], "#{at}/source", required: false)
    end

    def pointer_violations(source, at, required:)
      return required ? [ "#{at} is required" ] : [] if source.nil?
      return object(source, at) unless source.is_a?(Hash)

      keys(source, %w[pointer], at: at) +
        (source["pointer"].to_s.start_with?("/") ? [] : [ "#{at}/pointer must start with /" ])
    end

    # Exact key set: anything unlisted is out of contract, anything required and absent is a failure.
    def keys(object, required, optional: [], at: nil)
      prefix = at ? "#{at} " : ""
      missing = required - object.keys
      unexpected = object.keys - required - optional

      [
        missing.any? ? "#{prefix}is missing #{missing.join(', ')}" : nil,
        unexpected.any? ? "#{prefix}has unexpected #{unexpected.join(', ')}" : nil
      ].compact
    end

    def array(value, at, min: 0, &item)
      return [ "#{at} must be an array" ] unless value.is_a?(Array)
      return [ "#{at} must hold at least #{min}" ] if value.size < min

      value.each_with_index.flat_map { |element, index| item.call(element, "#{at}/#{index}") }
    end

    def object(value, at)
      value.is_a?(Hash) ? [] : [ "#{at} must be an object" ]
    end

    def string(value, at)
      value.is_a?(String) ? [] : [ "#{at} must be a string" ]
    end

    def integer(value, at)
      value.is_a?(Integer) ? [] : [ "#{at} must be an integer" ]
    end

    def counter(value, at)
      value.is_a?(Integer) && !value.negative? ? [] : [ "#{at} must be a non-negative integer" ]
    end

    def enumerated(value, allowed, at)
      allowed.include?(value) ? [] : [ "#{at} must be one of #{allowed.join(', ')}" ]
    end
  end
end
