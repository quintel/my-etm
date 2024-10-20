# frozen_string_literal: true

# Contains methods concerning featured scenarios
module SavedScenario::Featured
  def featured?
    featured_scenario.present?
  end

  def featured_owner_name
    featured? ? featured_scenario.owner.name : owners.first.name
  end

  def localized_title(locale)
    featured? ? featured_scenario.localized_title(locale) : title
  end

  def localized_description(locale)
    featured? ? featured_scenario.localized_description(locale) : description
  end
end
