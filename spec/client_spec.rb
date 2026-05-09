# frozen_string_literal: true

require "spec_helper"

RSpec.describe Payhub::Client do
  let(:base_url) { "https://stub.payhub.test" }
  let(:client) { described_class.new("phk_a.b", base_url: base_url, max_retries: 0) }

  it "rejects a malformed API key" do
    expect { described_class.new("not-a-key") }.to raise_error(ArgumentError)
  end

  it "creates a payment, sets headers, and decodes the typed payment" do
    body = {
      id: "pay_1", status: "requires_action", psp: "sadad", psp_ref: "TXN_1",
      next_action: {type: "otp_required", psp_ref: "TXN_1", masked_destination: "2189...12"},
      amount_minor: 4500, currency: "LYD", merchant_order_ref: "ord-1"
    }.to_json

    stub = stub_request(:post, "#{base_url}/v1/payments")
      .with(headers: {"Authorization" => "Bearer phk_a.b"})
      .to_return(status: 201, body: body, headers: {"Content-Type" => "application/json"})

    p = client.payments.create({psp: "sadad", merchant_order_ref: "ord-1", amount_minor: 4500})
    expect(p.status).to eq("requires_action")
    expect(p.next_action).to be_a(Payhub::NextAction::OtpRequired)
    expect(stub).to have_been_requested
  end

  it "maps 401 to AuthenticationError" do
    stub_request(:get, "#{base_url}/v1/health")
      .to_return(status: 401, body: '{"error":{"code":"hub.unauthenticated","message":"no"}}')
    expect { client.health.check }.to raise_error(Payhub::Errors::AuthenticationError)
  end

  it "retries on 503 then succeeds" do
    retrying = described_class.new("phk_a.b", base_url: base_url, max_retries: 2)
    stub_request(:get, "#{base_url}/v1/health")
      .to_return({status: 503, body: '{"error":{"code":"hub.unavailable","message":"x"}}'},
        {status: 200, body: '{"status":"ok","psps":["sadad"]}',
         headers: {"Content-Type" => "application/json"}})
    h = retrying.health.check
    expect(h.status).to eq("ok")
  end
end
