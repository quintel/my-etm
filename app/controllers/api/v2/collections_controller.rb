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
      def index
        page, collections = paginated(
          current_user.collections
            .accessible_by(current_ability)
            .kept
            .includes(:version, :user, :scenarios, :saved_scenarios)
            .order(created_at: :desc)
        )

        render_collection(collections, with: CollectionSerialiser, meta: pagination_meta(page))
      end

      # GET api/v2/collections/:id
      def show
        render_resource(@collection, with: CollectionSerialiser)
      end

      # POST api/v2/collections
      def create
        attributes = validated(CollectionCreateContract, create_params)
        return if attributes.nil?

        render_write(
          Api::CreateCollection.new.call(
            user: current_user,
            # Not a v2 member, temporary workaround because the column defaults to true.
            params: attributes.merge(interpolation: false)
          ),
          with: CollectionSerialiser, status: :created
        )
      end

      # PUT/PATCH api/v2/collections/:id
      def update
        attributes = validated(CollectionUpdateContract, update_params)
        return if attributes.nil?

        render_write(
          Api::UpdateCollection.new.call(collection: @collection, params: attributes),
          with: CollectionSerialiser
        )
      end

      # DELETE api/v2/collections/:id
      def destroy
        return render_validation_errors(@collection.errors) unless @collection.destroy

        render_no_content
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
        members_of(CollectionCreateContract, CollectionUpdateContract)
      end

      # Api::V1 renders Collection's error keys verbatim, so these are translated, not renamed.
      def member_aliases
        { scenarios: :saved_scenario_ids, collection_saved_scenarios: :saved_scenario_ids }
      end

      def create_params
        resource_params(:title, :version, saved_scenario_ids: [])
          .tap { |attributes| attributes.require(:saved_scenario_ids) }
      end

      def update_params
        resource_params(:title, saved_scenario_ids: [])
      end
    end
  end
end
