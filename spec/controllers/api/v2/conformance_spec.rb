# frozen_string_literal: true

require "rails_helper"
require "prism"

RSpec.describe "Api::V2 envelope conformance" do

  let(:raw_output) { %i[render head send_data send_file response_body=] }

  def raw_output_calls(source)
    result = Prism.parse(source)
    raise "source did not parse: #{result.errors.map(&:message).join(', ')}" unless result.success?

    collect(result.value)
  end

  def collect(node, found = [])
    found << "#{node.name} on line #{node.location.start_line}" if raw_output_call?(node)
    node.compact_child_nodes.each { |child| collect(child, found) }

    found
  end

  # A primitive reached through anything else is some other object's method, not the controller's.
  def raw_output_call?(node)
    return false unless node.is_a?(Prism::CallNode)
    return false unless node.receiver.nil? || node.receiver.is_a?(Prism::SelfNode)

    raw_output.include?(node.name)
  end

  {
    "render json: { foo: 1 }" => "render",
    "render(json: { foo: 1 })" => "render",
    "head :no_content" => "head",
    "self.response_body = 'raw'" => "response_body="
  }.each do |line, name|
    it "detects #{line}" do
      expect(raw_output_calls("def act\n  #{line}\nend\n")).to include(/#{Regexp.escape(name)}/)
    end
  end

  it "does not flag calls to the sanctioned envelope helpers" do
    source = <<~RUBY
      def show
        render_resource(@thing, with: ThingSerialiser)
      end

      def destroy
        render_no_content
      end
    RUBY

    expect(raw_output_calls(source)).to be_empty
  end

  it "ignores a primitive named in a comment, a string, or on another object" do
    source = <<~RUBY
      def show
        Rails.logger.info("would render json: here")
        render_resource(list.head, with: ThingSerialiser)
      end
    RUBY

    expect(raw_output_calls(source)).to be_empty
  end

  v2_controllers = Rails.root.glob("app/controllers/api/v2/**/*_controller.rb")

  v2_controllers.each do |file|
    it "#{file.relative_path_from(Rails.root)} renders only through the envelope helpers" do
      calls = raw_output_calls(file.read)

      expect(calls).to be_empty,
        "#{file} calls #{calls.join(', ')} directly, out of contract for Api::V2; " \
        "use an Api::V2::Responses envelope helper instead"
    end
  end
end
