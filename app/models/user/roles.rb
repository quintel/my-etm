module User::Roles
  ROLES = {
    1 => :scenario_viewer,
    2 => :scenario_collaborator,
    3 => :scenario_owner
  }.freeze

  def self.all
    ROLES.keys
  end

  def self.index_of(role)
    ROLES.key(role)
  end

  def self.name_for(id)
    ROLES[id]
  end

  def self.roles
    ROLES
  end

  # The ScenarioAccess level a role gives, or nil without a role
  def self.access_level(role_id)
    return unless role_id

    role_id >= index_of(:scenario_collaborator) ? ScenarioAccess::WRITE : ScenarioAccess::READ
  end
end
