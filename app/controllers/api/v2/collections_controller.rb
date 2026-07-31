module Api
  module V2
    class CollectionsController < BaseController
      include Api::V2::Serialisable

      # TODO: @Louis hook in here for resource auth
      load_and_authorize_resource(class: Collection, only: %i[index show])

      # GET api/v2/collections
      def index
        render_ok(
          serialise_collection(
            current_user.collections.kept.order(created_at: :desc)
          )
        )
      end

      # GET api/v2/collections/:id
      def show
        render json: serialise(@collection), status: :ok
      end

      # POST api/v2/collections
      def create;end

      # PUT/PATCH api/v2/collections/:id
      def update;end

      # DELETE api/v2/collections/:id
      def destroy;end

      # PUT api/v2/collections/:id/discard
      def discard;end

      # PUT api/v2/collections/:id/restore
      def restore;end
    end
  end
end
