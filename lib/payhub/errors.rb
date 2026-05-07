# frozen_string_literal: true

# Typed exception hierarchy mirroring app/core/errors.py. Maps the server's
# {error: {code, message, details, request_id}} envelope plus HTTP status to
# a precise subclass so callers `rescue Payhub::Errors::AuthenticationError`
# instead of inspecting strings.

module Payhub
  module Errors
    class Error < StandardError; end

    class APIError < Error
      attr_reader :code, :http_status, :details, :request_id

      def initialize(message, code:, http_status:, details: nil, request_id: nil)
        msg = request_id ? "#{message} [request_id=#{request_id}]" : message
        super(msg)
        @code = code
        @http_status = http_status
        @details = details || {}
        @request_id = request_id
      end
    end

    class AuthenticationError < APIError; end
    class PermissionError < APIError; end
    class NotFoundError < APIError; end
    class ValidationError < APIError; end
    class IdempotencyConflictError < APIError; end

    class RateLimitedError < APIError
      attr_reader :retry_after

      def initialize(message, retry_after: nil, **kwargs)
        super(message, **kwargs)
        @retry_after = retry_after
      end
    end

    class GatewayError < APIError; end
    class ServerError < APIError; end

    class TransportError < Error; end
    class TimeoutError < TransportError; end
    class ConnectionError < TransportError; end
    class DecodeError < TransportError; end

    class << self
      def from_envelope(envelope, http_status, retry_after: nil)
        err = (envelope.is_a?(Hash) && envelope["error"].is_a?(Hash)) ? envelope["error"] : {}
        code = err["code"] || "hub.unknown"
        message = err["message"] || "HTTP #{http_status}"
        details = err["details"] || {}
        request_id = err["request_id"]
        common = {code: code, http_status: http_status, details: details, request_id: request_id}

        case http_status
        when 401 then AuthenticationError.new(message, **common)
        when 403 then PermissionError.new(message, **common)
        when 404 then NotFoundError.new(message, **common)
        when 409 then IdempotencyConflictError.new(message, **common)
        when 422 then ValidationError.new(message, **common)
        when 429 then RateLimitedError.new(message, retry_after: retry_after, **common)
        else
          if (500..599).cover?(http_status)
            code.start_with?("gateway.") ? GatewayError.new(message, **common) : ServerError.new(message, **common)
          else
            APIError.new(message, **common)
          end
        end
      end
    end
  end
end
