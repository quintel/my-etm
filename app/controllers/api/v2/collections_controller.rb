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
      # Scoped based on the caller's access.
      # TODO: unpaginated.
      def index
        collections = current_user.collections
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
        return if reject_unresolvable_members(attributes[:saved_scenario_ids])

        Api::CreateCollection.new.call(
          user: current_user,
          params: attributes.to_h.symbolize_keys
        ).either(
          ->(collection) { render_resource(collection, with: CollectionSerialiser, status: :created) },
          ->(errors)     { render_validation_errors(errors) }
        )
      end

      # PUT/PATCH api/v2/collections/:id
      def update
        attributes = update_params
        return if reject_unresolvable_members(attributes[:saved_scenario_ids])

        Api::UpdateCollection.new.call(
          collection: @collection,
          params: attributes.to_h.symbolize_keys
        ).either(
          ->(collection) { render_resource(collection, with: CollectionSerialiser) },
          ->(errors)     { render_validation_errors(errors) }
        )
      end

      # DELETE api/v2/collections/:id
      def destroy
        Api::V2::DestroyCollection.new.call(collection: @collection).either(
          ->(_collection) { head :no_content },
          ->(errors)      { render_validation_errors(errors) }
        )
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
        collection = params.require(:collection)
        collection.require(:saved_scenario_ids)

        collection
          .permit(:title, :area_code, :end_year, :version, :interpolation, saved_scenario_ids: [])
          .with_defaults(interpolation: false)
      end

      def update_params
        params.require(:collection).permit(:title, :area_code, :end_year, saved_scenario_ids: [])
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
        return SavedScenario.where(id: ids).pluck(:id).to_set if owner.admin?

        SavedScenarioUser
          .where(saved_scenario_id: ids, user_id: owner.id)
          .pluck(:saved_scenario_id)
          .to_set
      end
    end
  end
end
