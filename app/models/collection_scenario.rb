# frozen_string_literal: true

# A scenario used by a Collection.
class CollectionScenario < ApplicationRecord
  belongs_to :collection

  def version
    collection.version
  end
end
