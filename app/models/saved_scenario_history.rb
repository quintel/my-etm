# frozen_string_literal: true

class SavedScenarioHistory < Dry::Struct
  # Extend and include ActiveModel to make form_for work
  extend ActiveModel::Naming
  include ActiveModel::AttributeMethods
  include ActiveModel::Conversion

  attribute :user_name,        Dry::Types["strict.string"]
  attribute :scenario_id, Dry::Types["strict.integer"]
  attribute :description,     Dry::Types["strict.string"]
  attribute :updated_at,  Dry::Types["strict.string"]
  attribute :frozen,      Dry::Types["strict.bool"]

  attr_reader :errors

  def self.from_params(params)
    SavedScenarioHistory.new(**params.to_h.symbolize_keys)
  end

  def initialize(attributes = {})
    super

    @errors = ActiveModel::Errors.new(self)
  end

  def persisted?
    false
  end

  def valid?
    # TODO: Do we need more validation? Like message length? Add a contract!
    # attributes = to_hash
    # schema = SavedScenarioHistory::Contract.new.call(attributes)
    # @errors = schema.errors(locale: I18n.locale).to_h.values.flatten

    @errors.empty?
  end
end
