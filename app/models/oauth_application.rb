# frozen_string_literal: true

class OAuthApplication < ApplicationRecord
  include Doorkeeper::Orm::ActiveRecord::Mixins::Application

  belongs_to :version
  has_one :staff_application, foreign_key: :application_id, dependent: :destroy
  validates :uri, presence: true, 'doorkeeper/redirect_uri': true
end
