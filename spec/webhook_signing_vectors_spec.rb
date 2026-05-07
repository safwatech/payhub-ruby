# frozen_string_literal: true

require "spec_helper"

RSpec.describe Payhub::WebhookEvent do
  vectors = JSON.parse(File.read(VECTORS_PATH.join("webhook-signing.json")))

  vectors["cases"].each do |c|
    it "vector: #{c["name"]}" do
      secret = [c["secret_hex"]].pack("H*")
      body = Base64.decode64(c["body_b64"])
      header = c["header"]
      tolerance = c["tolerance_seconds"]
      now = c["now"]

      case c["expect"]
      when "ok"
        result = described_class.verify(secret, body, header,
          tolerance_seconds: tolerance, now: now)
        expect(result).to be_a(Payhub::WebhookEventPayload)
      when "TimestampOutOfTolerance"
        expect {
          described_class.verify(secret, body, header,
            tolerance_seconds: tolerance, now: now)
        }.to raise_error(Payhub::TimestampOutOfToleranceError)
      when "InvalidSignature"
        expect {
          described_class.verify(secret, body, header,
            tolerance_seconds: tolerance, now: now)
        }.to raise_error(Payhub::InvalidSignatureError)
      when "MalformedHeader"
        expect {
          described_class.verify(secret, body, header,
            tolerance_seconds: tolerance, now: now)
        }.to raise_error(Payhub::MalformedHeaderError)
      else
        raise "unknown expect: #{c["expect"]} (#{c["name"]})"
      end
    end
  end

  it "decodes a valid event into a typed payload" do
    c = vectors["cases"].find { |x| x["name"] == "valid_v1" }
    secret = [c["secret_hex"]].pack("H*")
    body = Base64.decode64(c["body_b64"])
    ev = described_class.verify(secret, body, c["header"],
      tolerance_seconds: c["tolerance_seconds"], now: c["now"])
    expect(ev.id).to eq("evt_1")
    expect(ev.type).to eq("payment.succeeded")
    expect(ev.payment_id).to eq("pay_1")
  end
end
