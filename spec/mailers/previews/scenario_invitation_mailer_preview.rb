class ScenarioInvitationMailerPreview < ActionMailer::Preview
  def invite_user
    ScenarioInvitationMailer.invite_user(
      'test@example.com',
      'John Doe',
      'scenario_collaborator',
      { id: 1, title: 'Test Scenario' }
    )
  end
end
