# frozen_string_literal: true

module Identity
  class NewsletterStatusRowComponent < ApplicationComponent
    include ButtonHelper

    def initialize(subscribed:, audience:)
      @subscribed = subscribed
      @audience = audience
    end
  end
end
