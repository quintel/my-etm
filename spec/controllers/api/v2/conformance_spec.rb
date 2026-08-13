# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V2 envelope conformance" do
  def raw_render_json?(source)
    source.lines.any? { |line| line.split("#", 2).first.to_s =~ /\brender\s+json:/ }
  end

  it "detects a raw render json: call" do
    expect(raw_render_json?("def show\n  render json: { foo: 1 }\nend\n")).to be(true)
  end

  it "does not flag calls to the sanctioned envelope helpers" do
    source = <<~RUBY
      def show
        render_resource(@thing)
      end

      def index
        render_collection(@things, meta: { pagination: {} })
      end
    RUBY

    expect(raw_render_json?(source)).to be(false)
  end

  it "ignores a mention of render json: inside a comment" do
    expect(raw_render_json?("# render json: is out of contract here\nrender_resource(@thing)\n")).to be(false)
  end

  v2_controllers = Rails.root.glob("app/controllers/api/v2/**/*_controller.rb")

  v2_controllers.each do |file|
    it "#{file.relative_path_from(Rails.root)} does not call render json: directly" do
      expect(raw_render_json?(file.read)).to be(false),
        "#{file} calls render json: directly, out of contract for Api::V2; " \
        "use a Serialisable envelope helper instead"
    end
  end
end
