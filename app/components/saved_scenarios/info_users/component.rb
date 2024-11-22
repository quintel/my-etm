module SavedScenarios::InfoUsers
  class Component < ApplicationComponent
    option :users
    option :title
    option :color,  default: proc { 'bg-midnight-900' }
    option :privacy, default: proc { true }

    # Initials to show
    def initials_for(saved_scenario_user)
      saved_scenario_user.initials.capitalize
    end

    def hover_text_for(saved_scenario_user)
      if saved_scenario_user.name.present?
        "#{saved_scenario_user.name} (#{email_for(saved_scenario_user)})"
      else
        email_for(saved_scenario_user)
      end
    end

    def email_for(saved_scenario_user)
      if @privacy
        saved_scenario_user.email.gsub(/^.*?(?=@)/, "\*\*\*")
      else
        saved_scenario_user.email
      end
    end
  end
end
