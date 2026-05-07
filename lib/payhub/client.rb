# frozen_string_literal: true

require "json"
require "net/http"
require "securerandom"
require "uri"
require "rbconfig"

require_relative "errors"
require_relative "types"
require_relative "version"

module Payhub
  # Synchronous PayHub client. Thread-safe — share one instance per process;
  # internally each request opens a fresh Net::HTTP connection (keep-alive
  # is delegated to the OS-level connection pool of the HTTP server tier).
  class Client
    DEFAULT_BASE_URL = "https://app.payhub.ly"
    DEFAULT_TIMEOUT = 30
    DEFAULT_RETRIES = 2

    attr_reader :payments, :health

    def initialize(api_key, base_url: DEFAULT_BASE_URL, timeout: DEFAULT_TIMEOUT,
      max_retries: DEFAULT_RETRIES, http_client: nil, user_agent_suffix: nil)
      raise ArgumentError, "PayHub API key must start with 'phk_'" unless api_key.is_a?(String) && api_key.start_with?("phk_")
      @api_key = api_key
      @base_url = base_url.sub(%r{/+$}, "")
      @timeout = timeout
      @max_retries = max_retries
      @http_client = http_client
      @user_agent = build_user_agent(user_agent_suffix)
      @payments = Payments.new(self)
      @health = HealthResource.new(self)
    end

    # Internal request helper used by resource classes.
    def request(method, path, body: nil, idempotency_key: nil, retriable: true)
      attempts = retriable ? [@max_retries + 1, 1].max : 1
      last_err = nil
      attempts.times do |attempt|
        begin
          status, headers, raw = perform_request(method, path, body, idempotency_key)
        rescue Net::OpenTimeout, Net::ReadTimeout => e
          last_err = Errors::TimeoutError.new("payhub: timeout: #{e.message}")
        rescue SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, EOFError, IOError => e
          last_err = Errors::ConnectionError.new("payhub: connection: #{e.message}")
        else
          if (200..299).cover?(status)
            return decode_2xx(raw)
          end
          err = build_api_error(status, raw, headers)
          if retriable && (status >= 500 || status == 429) && attempt + 1 < attempts
            wait = retry_after(headers) || backoff_seconds(attempt)
            sleep(wait)
            last_err = err
            next
          end
          raise err
        end
        sleep(backoff_seconds(attempt)) if attempt + 1 < attempts
      end
      raise last_err if last_err
      raise Errors::Error, "payhub: unreachable retry loop"
    end

    private

    def perform_request(method, path, body, idempotency_key)
      uri = URI.parse(@base_url + path)
      req_class = case method
      when :get then Net::HTTP::Get
      when :post then Net::HTTP::Post
      when :delete then Net::HTTP::Delete
      else raise ArgumentError, "unsupported method: #{method}"
      end
      req = req_class.new(uri.request_uri)
      req["Authorization"] = "Bearer #{@api_key}"
      req["Accept"] = "application/json"
      req["User-Agent"] = @user_agent
      req["Idempotency-Key"] = idempotency_key if idempotency_key
      if body
        req["Content-Type"] = "application/json"
        req.body = JSON.generate(body)
      end

      http = @http_client || begin
        h = Net::HTTP.new(uri.host, uri.port)
        h.use_ssl = (uri.scheme == "https")
        h.open_timeout = @timeout
        h.read_timeout = @timeout
        h
      end
      resp = http.request(req)
      [resp.code.to_i, resp.to_hash.transform_keys(&:downcase), resp.body || ""]
    end

    def decode_2xx(raw)
      return nil if raw.nil? || raw.empty?
      JSON.parse(raw)
    rescue JSON::ParserError => e
      raise Errors::DecodeError, "payhub: decode: #{e.message}"
    end

    def build_api_error(status, raw, headers)
      envelope = parse_envelope(raw, status)
      Errors.from_envelope(envelope, status, retry_after: retry_after(headers))
    end

    def parse_envelope(raw, status)
      JSON.parse(raw)
    rescue JSON::ParserError, TypeError
      {"error" => {"code" => "hub.unknown", "message" => "HTTP #{status}"}}
    end

    def retry_after(headers)
      v = headers && (headers["retry-after"] || headers["Retry-After"])
      Array(v).first&.to_i
    end

    def backoff_seconds(attempt)
      base = 0.5 * (2**attempt)
      base * (0.8 + rand * 0.4)
    end

    def build_user_agent(suffix)
      base = "payhub-ruby/#{VERSION} (ruby #{RUBY_VERSION}; #{RbConfig::CONFIG["host_os"]})"
      suffix ? "#{base} #{suffix}" : base
    end

    class Payments
      def initialize(client)
        @c = client
      end

      def create(request, idempotency_key: nil)
        key = idempotency_key || SecureRandom.uuid
        raw = @c.request(:post, "/v1/payments", body: request, idempotency_key: key)
        Payment.from_raw(raw)
      end

      def confirm_otp(payment_id, code, idempotency_key: nil)
        key = idempotency_key || SecureRandom.uuid
        raw = @c.request(:post, "/v1/payments/#{payment_id}/otp",
          body: {code: code}, idempotency_key: key)
        Payment.from_raw(raw)
      end

      def refund(payment_id, amount_minor: nil, reason: nil, idempotency_key: nil)
        body = {}
        body[:amount_minor] = amount_minor unless amount_minor.nil?
        body[:reason] = reason unless reason.nil?
        key = idempotency_key || SecureRandom.uuid
        raw = @c.request(:post, "/v1/payments/#{payment_id}/refund",
          body: body, idempotency_key: key)
        Payment.from_raw(raw)
      end

      def retrieve(payment_id)
        Payment.from_raw(@c.request(:get, "/v1/payments/#{payment_id}"))
      end
    end

    class HealthResource
      def initialize(client)
        @c = client
      end

      def check
        Health.from_raw(@c.request(:get, "/v1/health"))
      end
    end
  end
end
