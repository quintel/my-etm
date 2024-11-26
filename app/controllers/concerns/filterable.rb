module Filterable
  def filter!(resource)
    store_filters(resource)
    apply_filters(resource)
  end

  private

  def store_filters(resource)
    unless session.key?(session_key_for(resource))
      session[session_key_for(resource)] = {}
    end

    session[session_key_for(resource)].merge!(filter_params_for(resource))
  end

  def filter_params_for(resource)
    params.permit(resource::FILTER_PARAMS)
  end

  def apply_filters(resource)
    resource.filter(session[session_key_for(resource)])
  end

  def session_key_for(resource)
    "#{resource.to_s.underscore}_filters"
  end
end
