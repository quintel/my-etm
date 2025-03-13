# frozen_string_literal: true

module Identity
  class NewsletterStatusRowComponent < ApplicationComponent
    include ButtonHelper
    include Turbo::FramesHelper

    def initialize(subscribed:, audience:)
      @subscribed = subscribed
      @audience = audience
    end
  end
end
