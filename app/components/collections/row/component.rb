module Collections::Row
  class Component < ApplicationComponent
    option :path
    option :collection

    # Fetch the first owner of the collection
    def first_owner
      @collection.user
    end

    # Generate initials for the owner
    def initials_for(user)
      user&.initials&.capitalize || "?"
    end
  end
end
