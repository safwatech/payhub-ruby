# frozen_string_literal: true

# Discriminated NextAction returned in payment.next_action.
#
# Ruby has no sealed-classes; instead, decode_next_action returns a frozen
# struct subclass keyed off the kind so callers can `case na in OtpRequired`.

module Payhub
  module NextAction
    OtpRequired = Struct.new(:psp_ref, :masked_destination, :expires_at, keyword_init: true) do
      def kind = :otp_required
    end

    Redirect = Struct.new(:url, :method, :fields, :expires_at, keyword_init: true) do
      def kind = :redirect
    end

    QR = Struct.new(:reference, :qr_payload, :expires_at, keyword_init: true) do
      def kind = :qr
    end

    Lightbox = Struct.new(:params, :script_url, keyword_init: true) do
      def kind = :lightbox
    end

    class << self
      def decode(raw)
        return nil if raw.nil?
        raise ArgumentError, "next_action must be an object or nil" unless raw.is_a?(Hash)

        case raw["type"]
        when "otp_required"
          OtpRequired.new(
            psp_ref: raw["psp_ref"].to_s,
            masked_destination: raw["masked_destination"].to_s,
            expires_at: raw["expires_at"]
          )
        when "redirect"
          Redirect.new(
            url: raw["url"].to_s,
            method: (raw["method"] || "GET").to_s.upcase,
            fields: (raw["fields"] || {}).each_with_object({}) { |(k, v), h| h[k.to_s] = v.to_s },
            expires_at: raw["expires_at"]
          )
        when "qr"
          QR.new(
            reference: raw["reference"].to_s,
            qr_payload: raw["qr_payload"].to_s,
            expires_at: raw["expires_at"]
          )
        when "lightbox"
          params = (raw["params"] || {}).each_with_object({}) { |(k, v), h| h[k.to_s] = v.to_s }
          Lightbox.new(params: params, script_url: params["lightbox_js_url"])
        else
          raise ArgumentError, "unknown next_action.type: #{raw["type"].inspect}"
        end
      end
    end
  end
end
