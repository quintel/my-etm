module Admin
  class CollectionsController < ApplicationController
    include AdminController
    include Pagy::Method
    include Filterable

    def index
      # Include Pagy to paginate @collections or any other resource
      @pagy_collections, @collections = pagy(
        Collection.kept.order(created_at: :desc)
      )

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    # Renders a partial of collections based on turbo search and filters
    #
    # GET admin/collections/list
    def list
      filtered = filter!(Collection)

      @pagy_collections, @collections =  pagy(filtered.kept)

      respond_to do |format|
        format.html { render(
          partial: "collections",
          locals: { collections: @collections, pagy_collections: @pagy_collections }
        ) }
        format.turbo_stream { render(:index) }
      end
    end
  end
end
