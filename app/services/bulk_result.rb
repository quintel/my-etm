# frozen_string_literal: true

# The outcome of a bulk service call: exactly one Item per submitted item, in the order submitted.
#
# `identifier` is retained only so Api::V1 can keep rendering its identifier-keyed error hash.
class BulkResult
  Item = Data.define(:index, :identifier, :value, :code, :messages) do
    def self.ok(index:, identifier:, value:)
      new(index:, identifier:, value:, code: nil, messages: [])
    end

    def self.error(index:, identifier:, code:, messages:)
      new(index:, identifier:, value: nil, code:, messages: Array(messages))
    end

    def self.invalid(index:, identifier:, record:)
      error(index:, identifier:, code: :validation_failed, messages: record.errors.full_messages)
    end

    def ok?
      code.nil?
    end

    # Collapses a single item back onto the ServiceResult the non-bulk callers expect.
    def to_service_result
      ok? ? ServiceResult.success(value) : ServiceResult.failure(messages)
    end
  end

  attr_reader :items

  def initialize(items)
    @items = items
  end

  def successful?
    items.all?(&:ok?)
  end

  def failure?
    !successful?
  end

  # The applied items' values, matching ServiceResult#value.
  def value
    items.select(&:ok?).map(&:value)
  end
end
