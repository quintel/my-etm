# frozen_string_literal: true

class ApplicationComponent < ViewComponent::Base
  extend Dry::Initializer
  include HeroiconHelper
end
