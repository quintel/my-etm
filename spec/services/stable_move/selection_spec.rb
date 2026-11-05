# frozen_string_literal: true

require "rails_helper"

describe StableMove::Selection do
  let(:path) { Pathname.new(Dir.mktmpdir).join("selection.yml") }

  def load(yaml)
    path.write(yaml)
    described_class.load(path)
  end

  it "reads the datasets and the saved scenario ids" do
    expect(load(<<~YAML)).to eq(datasets: [ "nl" ], handpicked: [ 12, 34 ])
      datasets:
        - nl
      saved_scenarios:
        - 12 # asked by someone
        - 34
        - 12
    YAML
  end

  it "accepts no datasets" do
    expect(load("saved_scenarios: [12]")).to eq(datasets: [], handpicked: [ 12 ])
  end

  it "refuses ids that aren't numbers" do
    expect { load("saved_scenarios: [12, 34 56]") }.to raise_error(StableMove::Error, /34 56/)
  end

  it "refuses unknown keys" do
    expect { load("dataset: [nl]") }.to raise_error(StableMove::Error, /unknown keys: dataset/)
  end

  it "refuses a file that selects nothing" do
    expect { load("datasets: []") }.to raise_error(StableMove::Error, /no datasets and no saved scenarios/)
  end

  it "refuses a missing file" do
    expect { described_class.load(path) }.to raise_error(StableMove::Error, /is missing/)
  end
end
