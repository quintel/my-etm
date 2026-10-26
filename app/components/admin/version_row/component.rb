module Admin::VersionRow
  class Component < ApplicationComponent
    include ButtonHelper

    option :version

    def path
      version.model_url
    end
  end
end
