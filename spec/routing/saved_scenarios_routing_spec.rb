require "rails_helper"

RSpec.describe SavedScenariosController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/saved_scenarios").to route_to("saved_scenarios#index")
    end

    it "routes to #new" do
      expect(get: "/saved_scenarios/new").to route_to("saved_scenarios#new")
    end

    it "routes to #show" do
      expect(get: "/saved_scenarios/1").to route_to("saved_scenarios#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/saved_scenarios/1/edit").to route_to("saved_scenarios#edit", id: "1")
    end

    it "routes to #update via PUT" do
      expect(put: "/saved_scenarios/1").to route_to("saved_scenarios#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/saved_scenarios/1").to route_to("saved_scenarios#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/saved_scenarios/1").to route_to("saved_scenarios#destroy", id: "1")
    end
  end
end
