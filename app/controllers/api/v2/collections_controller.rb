module Api
  module V2
    class CollectionsController < BaseController
      self.resource_param_key = :collection

      before_action :require_user, only: %i[index]

      load_and_authorize_resource(
        class: Collection, only: %i[show update destroy discard restore]
      )

      authorize_resource(class: Collection, only: %i[index])

      before_action only: %i[create] do
        authorize!(:create, Collection)
      end

      # GET api/v2/collections
      #
      # The caller's own collections, then filtered by the ability.
      # TODO: unpaginated.
      def index
        collections = current_user.collections
          .accessible_by(current_ability)
          .kept
          .includes(:version, :user, :scenarios, :saved_scenarios)
          .order(created_at: :desc)

        render_collection(collections, with: CollectionSerialiser)
      end

      # GET api/v2/collections/:id
      def show
        render_resource(@collection, with: CollectionSerialiser)
      end

      # POST api/v2/collections
      def create
        attributes = create_params
        return if reject_request(attributes)

        render_write(
          Api::CreateCollection.new.call(user: current_user, params: attributes.to_h.symbolize_keys),
          with: CollectionSerialiser, status: :created
        )
      end

      # PUT/PATCH api/v2/collections/:id
      def update
        attributes = update_params
        return if reject_request(attributes)

        render_write(
          Api::UpdateCollection.new.call(
            collection: @collection, params: attributes.to_h.symbolize_keys
          ),
          with: CollectionSerialiser
        )
      end

      # DELETE api/v2/collections/:id
      def destroy
        return render_validation_errors(@collection.errors) unless @collection.destroy

        head :no_content
      end

      # PUT api/v2/collections/:id/discard
      def discard
        @collection.discard

        render_resource(@collection, with: CollectionSerialiser)
      end

      # PUT api/v2/collections/:id/restore
      def restore
        @collection.undiscard

        render_resource(@collection, with: CollectionSerialiser)
      end

      private

      def request_members
        %i[title area_code end_year version interpolation saved_scenario_ids]
      end

      # Api::V1 renders Collection's error keys verbatim, so :scenarios is translated, not renamed.
      def member_aliases
        { scenarios: :saved_scenario_ids }
      end

      # The column defaults to true, which would fail every collection with more than one member.
      def create_params
        resource_params(
          :title, :area_code, :end_year, :version, :interpolation, saved_scenario_ids: []
        ).tap { |attributes| attributes.require(:saved_scenario_ids) }
          .with_defaults(interpolation: false)
      end

      def update_params
        resource_params(:title, :area_code, :end_year, saved_scenario_ids: [])
      end

      # Renders and returns true when the request names something that cannot be resolved
      def reject_request(attributes)
        reject_unknown_version(attributes[:version]) ||
          reject_oversized(:saved_scenario_ids, attributes[:saved_scenario_ids]) ||
          reject_unresolvable_members(attributes[:saved_scenario_ids])
      end

      # Renders and returns true when a member cannot be resolved, naming the position that failed.
      def reject_unresolvable_members(ids)
        missing = unresolvable_member_indices(ids)
        return false if missing.empty?

        render_validation_errors(
          saved_scenario_ids: missing.index_with { [ "Saved scenario not found" ] }
        )
        true
      end

      # Ids the contract itself rejects are left to it, so a malformed id still reads as malformed.
      def unresolvable_member_indices(ids)
        ids = Array(ids).map(&:to_i)
        return [] if ids.empty?

        visible = visible_member_ids(ids)

        ids.each_index.reject { |index| ids[index] < 1 || visible.include?(ids[index]) }
      end

      def visible_member_ids(ids)
        owner = @collection&.user || current_user
        scenarios = SavedScenario.kept.where(id: ids)
        return scenarios.pluck(:id).to_set if owner.admin?

        SavedScenarioUser
          .where(saved_scenario_id: scenarios.select(:id), user_id: owner.id)
          .pluck(:saved_scenario_id)
          .to_set
      end
    end
  end
end
