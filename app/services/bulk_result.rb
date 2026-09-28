# frozen_string_literal: true

# The outcome of a bulk service call: exactly one Item per submitted item, in the order submitted.
#
# TODO: drop `identifier` once v1 and v3 retire; only Api::V1's identifier-keyed error hash reads
# it, and a v2 batch names an item by the position it was submitted at.
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

    # A non-bulk caller is handed this instead of a BulkResult. Every one of them is the web UI, so
    # it stays when v1 goes.
    def to_service_result
      ok? ? ServiceResult.success(value) : ServiceResult.failure(messages)
    end
  end

  attr_reader :items

  def initialize(items)
    @items = items
  end

  # A bulk call's outcome is rendered by v2 from the items themselves. successful?, failure? and
  # value are a v1-compatible face, added so Api::V1's existing controller kept working when the
  # services changed to answer with this.
  #
  # TODO: drop successful?, failure? and value once v1 and v3 retire.
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
