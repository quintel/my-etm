# frozen_string_literal: true

class ContactUsMessage < Dry::Struct
  # Extend and include ActiveModel to make form_for work
  extend ActiveModel::Naming
  include ActiveModel::AttributeMethods
  include ActiveModel::Conversion

  attribute :name,    Dry::Types['strict.string']
  attribute :email,   Dry::Types['strict.string']
  attribute :message, Dry::Types['strict.string']

  attr_reader :errors

  def self.from_params(params)
    ContactUsMessage.new(**params.to_h.symbolize_keys)
  end

  def initialize(attributes = {})
    super

    @errors = ActiveModel::Errors.new(self)
  end

  def persisted?
    false
  end

  def valid?
    attributes = to_hash
    schema = ContactUs::Contract.new.call(attributes)
    @errors = schema.errors(locale: I18n.locale).to_h.values.flatten

    @errors.empty?
  end
end
