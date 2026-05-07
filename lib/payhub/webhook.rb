# frozen_string_literal: true

require "openssl"
require "json"

# Webhook signature verification.
#
# Algorithmic reference: app/core/signing.py. Header is
#   Hub-Signature: t=<unix>,v1=<hmac_sha256_hex>
# Signed bytes: "#{t}.".b + raw_body. Default tolerance ±300 s.
#
# Every PayHub SDK ports the same algorithm; the canonical fixtures at
# sdks/shared/test-vectors/webhook-signing.json are the spec.

module Payhub
  class WebhookSignatureError < StandardError; end

  class MalformedHeaderError < WebhookSignatureError; end

  class TimestampOutOfToleranceError < WebhookSignatureError
    attr_reader :skew_seconds

    def initialize(skew_seconds)
      super("webhook timestamp out of tolerance: #{skew_seconds}s skew")
      @skew_seconds = skew_seconds
    end
  end

  class InvalidSignatureError < WebhookSignatureError; end

  WebhookEventPayload = Struct.new(
    :id, :type, :payment_id, :prev_status, :new_status, :source, :payload, :created_at,
    keyword_init: true
  )

  module WebhookEvent
    DEFAULT_TOLERANCE_SECONDS = 300

    class << self
      # Verify a webhook delivery and return the decoded event.
      # Raises Payhub::MalformedHeaderError, TimestampOutOfToleranceError, or InvalidSignatureError.
      def verify(secret, body, header, tolerance_seconds: DEFAULT_TOLERANCE_SECONDS, now: nil)
        secret_b = secret.is_a?(String) ? secret.b : secret.to_s.b
        body_b = body.is_a?(String) ? body.b : body.to_s.b

        t, v1 = parse_header(header)
        wall_now = now || Time.now.to_i
        skew = (wall_now - t).abs
        raise TimestampOutOfToleranceError.new(skew) if skew > tolerance_seconds

        signed = "#{t}.".b + body_b
        expected = OpenSSL::HMAC.hexdigest("SHA256", secret_b, signed)
        raise InvalidSignatureError, "Hub-Signature v1 does not match" unless secure_compare(expected, v1)

        decode_payload(body_b)
      end

      private

      def parse_header(header)
        parts = {}
        header.to_s.split(",").each do |seg|
          k, _, v = seg.partition("=")
          parts[k.strip] = v.strip unless v.empty?
        end
        unless parts.key?("t") && parts.key?("v1")
          raise MalformedHeaderError, "Hub-Signature missing t or v1: #{header.inspect}"
        end
        begin
          t = Integer(parts["t"], 10)
        rescue ArgumentError, TypeError
          raise MalformedHeaderError, "Hub-Signature t is not an integer: #{parts["t"].inspect}"
        end
        [t, parts["v1"]]
      end

      def secure_compare(a, b)
        return false unless a.bytesize == b.bytesize
        OpenSSL.fixed_length_secure_compare(a.b, b.b)
      end

      def decode_payload(body_bytes)
        return WebhookEventPayload.new if body_bytes.empty?
        begin
          raw = JSON.parse(body_bytes)
        rescue JSON::ParserError => e
          raise InvalidSignatureError, "webhook body is not JSON: #{e.message}"
        end
        raise InvalidSignatureError, "webhook body is not a JSON object" unless raw.is_a?(Hash)

        WebhookEventPayload.new(
          id: raw["id"].to_s,
          type: raw["type"].to_s,
          payment_id: raw["payment_id"].to_s,
          prev_status: raw["prev_status"],
          new_status: raw["new_status"].to_s,
          source: raw["source"].to_s,
          payload: raw["payload"] || {},
          created_at: raw["created_at"].to_s
        )
      end
    end
  end
end
