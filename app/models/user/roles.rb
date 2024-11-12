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

  def roles
    ROLES
  end
end
