json.extract!(saved_scenario, :id, :scenario_id, :scenario_id_history, :title, :description, :area_code, :end_year, :private, :created_at, :updated_at, :discarded_at, :created_at, :updated_at)
json.url(saved_scenario_url(saved_scenario, format: :json))
