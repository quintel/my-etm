# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreateVersion do
  let(:owner) { create(:admin) }

  context 'with a new tag' do
    let(:result) { described_class.call(tag: '2027', released_on: Date.new(2027, 1, 12), owner: owner) }
    let(:version) { result.value! }

    it 'returns success' do
      expect(result).to be_success
    end

    it 'creates a hidden version with the URL prefix of the tag' do
      expect(version).to have_attributes(tag: '2027', url_prefix: '2027.', hidden: true)
    end

    it 'creates an application for ETModel' do
      expect(version.oauth_applications.find_by(name: 'etmodel.2027')).to have_attributes(
        uri: 'https://2027.energytransitionmodel.com',
        redirect_uri: 'https://2027.energytransitionmodel.com/auth/identity/callback',
        confidential: true,
        first_party: true,
        owner: owner
      )
    end

    it 'creates an application for ETEngine' do
      expect(version.oauth_applications.find_by(name: 'engine.2027')).to have_attributes(
        uri: 'https://2027.engine.energytransitionmodel.com',
        redirect_uri: 'https://2027.engine.energytransitionmodel.com/auth/identity/callback'
      )
    end

    it 'gives the applications the scopes the apps sign in with' do
      expect(version.oauth_applications.map { |app| app.scopes.to_s }.uniq)
        .to eq([ CreateVersion::SCOPES ])
    end

    it 'generates client IDs and secrets' do
      expect(version.oauth_applications.map { |app| [ app.uid, app.plaintext_secret ] }.flatten)
        .to all(be_present)
    end
  end

  it 'can create a visible version' do
    expect(described_class.call(tag: '2027', released_on: Date.new(2027, 1, 12), hidden: false, owner: owner).value!.hidden)
      .to be(false)
  end

  it 'is owned by the robot user by default' do
    version = described_class.call(tag: '2027', released_on: Date.new(2027, 1, 12)).value!

    expect(version.oauth_applications.map(&:owner).uniq).to eq([ User.robot ])
  end

  [ '2027.01', '2027b', '2027-2', 'beta', '27' ].each do |tag|
    it "refuses #{tag}" do
      expect(described_class.call(tag:, released_on: Date.new(2027, 1, 12), owner: owner)).to be_failure
    end
  end

  context 'with a tag in another format' do
    let(:result) { described_class.call(tag: '2027.01', released_on: Date.new(2027, 1, 12), owner: owner) }

    it 'returns failure' do
      expect(result).to be_failure
    end

    it 'explains the tag format' do
      expect(result.failure.errors[:tag]).to include('must be a year, like 2027')
    end

    it 'creates nothing' do
      expect { result }.not_to change { [ Version.count, OAuthApplication.count ] }
    end
  end

  it 'saves the release date' do
    expect(described_class.call(tag: '2027', released_on: Date.new(2027, 1, 12), owner: owner).value!.released_on)
      .to eq(Date.new(2027, 1, 12))
  end

  context 'without a release date' do
    let(:result) { described_class.call(tag: '2027', released_on: nil, owner: owner) }

    it 'returns failure' do
      expect(result).to be_failure
    end

    it 'creates nothing' do
      expect { result }.not_to change { [ Version.count, OAuthApplication.count ] }
    end
  end

  context 'with a tag that already exists' do
    before { described_class.call(tag: '2027', released_on: Date.new(2027, 1, 12), owner: owner) }

    let(:result) { described_class.call(tag: '2027', released_on: Date.new(2027, 1, 12), owner: owner) }

    it 'returns failure' do
      expect(result).to be_failure
    end

    it 'creates no applications' do
      expect { result }.not_to change(OAuthApplication, :count)
    end
  end
end
