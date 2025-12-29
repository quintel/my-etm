# frozen_string_literal: true

require "rails_helper"

RSpec.describe SavedScenarioHistory, type: :model do
  describe ".from_params" do
    it "creates a SavedScenarioHistory with valid params" do
      params = {
        user_name: "John Doe",
        scenario_id: 123,
        description: "Test scenario",
        updated_at: "2025-12-23T10:00:00Z",
        frozen: false
      }

      history = described_class.from_params(params)

      expect(history.user_name).to eq("John Doe")
      expect(history.scenario_id).to eq(123)
      expect(history.description).to eq("Test scenario")
      expect(history.updated_at).to eq("2025-12-23T10:00:00Z")
      expect(history.frozen).to eq(false)
    end

    it "accepts nil updated_at to handle historical scenarios without timestamps" do
      params = {
        user_name: "John Doe",
        scenario_id: 123,
        description: "Old scenario",
        updated_at: nil,
        frozen: false
      }

      expect { described_class.from_params(params) }.not_to raise_error

      history = described_class.from_params(params)
      expect(history.updated_at).to be_nil
    end

    it "accepts empty string for updated_at" do
      params = {
        user_name: "John Doe",
        scenario_id: 123,
        description: "Test scenario",
        updated_at: "",
        frozen: false
      }

      expect { described_class.from_params(params) }.not_to raise_error

      history = described_class.from_params(params)
      expect(history.updated_at).to eq("")
    end
  end

  describe "#persisted?" do
    it "returns false" do
      history = described_class.new(
        user_name: "John Doe",
        scenario_id: 123,
        description: "Test",
        updated_at: "2025-12-23T10:00:00Z",
        frozen: false
      )

      expect(history.persisted?).to eq(false)
    end
  end

  describe "#valid?" do
    it "returns true when there are no errors" do
      history = described_class.new(
        user_name: "John Doe",
        scenario_id: 123,
        description: "Test",
        updated_at: "2025-12-23T10:00:00Z",
        frozen: false
      )

      expect(history.valid?).to eq(true)
    end
  end
end
