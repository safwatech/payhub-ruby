# frozen_string_literal: true

require_relative "next_action"

module Payhub
  Payment = Struct.new(
    :id, :status, :psp, :psp_ref, :next_action, :amount_minor,
    :currency, :merchant_order_ref, :hosted_checkout_url,
    keyword_init: true
  ) do
    def self.from_raw(raw)
      new(
        id: raw["id"].to_s,
        status: raw["status"].to_s,
        psp: raw["psp"].to_s,
        psp_ref: raw["psp_ref"],
        next_action: Payhub::NextAction.decode(raw["next_action"]),
        amount_minor: raw["amount_minor"].to_i,
        currency: raw["currency"].to_s,
        merchant_order_ref: raw["merchant_order_ref"].to_s,
        hosted_checkout_url: raw["hosted_checkout_url"]
      )
    end
  end

  # Refund row currently mirrors Payment.
  Refund = Payment

  Health = Struct.new(:status, :psps, keyword_init: true) do
    def self.from_raw(raw)
      new(status: raw["status"].to_s, psps: Array(raw["psps"]))
    end
  end
end
