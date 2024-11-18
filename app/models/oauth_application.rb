# frozen_string_literal: true

class OAuthApplication < ApplicationRecord
  include Doorkeeper::Orm::ActiveRecord::Mixins::Application

  has_many :staff_applications, foreign_key: :application_id, dependent: :destroy

  validates :uri, presence: true, 'doorkeeper/redirect_uri': true
end
