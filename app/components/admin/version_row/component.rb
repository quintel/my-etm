module Admin::VersionRow
  class Component < ApplicationComponent
    option :version

    def path
      version.model_url
    end
  end
end
