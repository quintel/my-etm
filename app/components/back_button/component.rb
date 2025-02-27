module BackButton
  class Component < ApplicationComponent
    include ButtonHelper

    def path
      if session[:previous_pages].present? && session[:previous_pages].size > 2
        session[:previous_pages].last(2).first
      end
    end
  end
end
