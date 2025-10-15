module Collections::EditableSavedScenario
  class Component < Collections::SavedScenario::Component
    option :hidden, default: proc { false }
    # Extend any methods or override as needed for editable scenarios
  end
end
