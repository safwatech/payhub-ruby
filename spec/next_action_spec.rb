# frozen_string_literal: true

require "spec_helper"

RSpec.describe Payhub::NextAction do
  fixtures = JSON.parse(File.read(VECTORS_PATH.join("next-action-fixtures.json")))

  expected_class = {
    "OtpRequired" => Payhub::NextAction::OtpRequired,
    "Redirect" => Payhub::NextAction::Redirect,
    "QR" => Payhub::NextAction::QR,
    "Lightbox" => Payhub::NextAction::Lightbox
  }

  fixtures["fixtures"].each do |fx|
    it "decodes #{fx["name"]} into #{fx["expect_kind"]}" do
      result = described_class.decode(fx["json"])
      expect(result).to be_a(expected_class.fetch(fx["expect_kind"]))
    end
  end

  it "returns nil on nil" do
    expect(described_class.decode(nil)).to be_nil
  end

  it "raises on unknown discriminator" do
    expect { described_class.decode({"type" => "new_thing"}) }.to raise_error(ArgumentError)
  end
end
