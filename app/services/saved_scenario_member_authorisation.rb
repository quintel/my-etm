# frozen_string_literal: true

# Splits submitted membership items into the ones a caller may apply and the ones they may not, so a
# batch mixing a permitted role change with an ownership change applies the former and refuses the
# latter at its own submitted position.
class SavedScenarioMemberAuthorisation
  include SavedScenarioUserLookup

  OWNER = User::Roles.index_of(:scenario_owner)
  REFUSAL = "Only an owner may grant or revoke ownership"

  def initialize(saved_scenario, submitted, permit_owners:)
    @saved_scenario = saved_scenario
    @submitted = submitted
    @permit_owners = permit_owners
  end

  # Runs the given bulk service over only the items this caller may apply, then merges the refusals
  # back so every item still reports at the position it arrived at.
  def apply
    return BulkResult.new(refusals.values) if permitted.empty?

    merge(yield(permitted.map(&:last)))
  end

  private

  attr_reader :saved_scenario, :submitted, :permit_owners

  def indexed
    @indexed ||= submitted.each_with_index.map { |params, index| [ index, params ] }
  end

  def permitted
    @permitted ||= indexed.reject { |index, _params| refusals.key?(index) }
  end

  def refusals
    @refusals ||= indexed.each_with_object({}) do |(index, params), refused|
      refused[index] = refusal(index, params) if ownership_change?(params)
    end
  end

  def merge(result)
    applied = permitted.map(&:first).zip(result.items).to_h

    BulkResult.new(indexed.map { |index, _params| refusals[index] || applied[index].with(index:) })
  end

  def ownership_change?(params)
    return false if permit_owners

    params[:role_id] == OWNER || owner_member?(params)
  end

  def refusal(index, params)
    BulkResult::Item.error(
      index:, identifier: extract_identifier(params), code: :forbidden, messages: [ REFUSAL ]
    )
  end

  def owner_member?(params)
    owner_members.any? do |member|
      next member.id == params[:id] if params[:id]
      next member.user_id == params[:user_id] if params[:user_id]

      params[:user_email].present? && member.email == params[:user_email]
    end
  end

  def owner_members
    @owner_members ||= members.where(role_id: OWNER).includes(:user).to_a
  end
end
