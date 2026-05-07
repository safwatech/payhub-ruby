# PayHub Ruby SDK

Official PayHub SDK for Ruby. Synchronous Net::HTTP transport, idempotent
retries, typed error hierarchy, webhook verifier, and a discriminated
`NextAction` you `case`-match on.

## Install

```bash
gem install payhub
```

Or in `Gemfile`:

```ruby
gem "payhub", "~> 1.0"
```

## Quickstart — Sadad OTP

```ruby
require "payhub"

client = Payhub::Client.new(ENV.fetch("PAYHUB_API_KEY"))

payment = client.payments.create(
  psp: "sadad",
  merchant_order_ref: "ord-42",
  amount_minor: 4500,
  currency: "LYD",
  customer: {msisdn: "218910000001", birth_year: 1990}
)

case payment.next_action
in Payhub::NextAction::OtpRequired => otp
  puts "Sadad sent OTP to #{otp.masked_destination}"
end

confirmed = client.payments.confirm_otp(payment.id, "111111")
puts confirmed.status # "succeeded"
```

## Webhook verification (Rails / Sinatra / Rack)

The single most important rule: **verify the raw request body**, not a
parsed Hash. Re-serializing the JSON before HMAC will corrupt the signature.

```ruby
# Rack / Sinatra
post "/webhooks/payhub" do
  body = request.body.read

  ev = Payhub::WebhookEvent.verify(
    secret: ENV.fetch("PAYHUB_WEBHOOK_SECRET"),
    body: body,
    header: request.env["HTTP_HUB_SIGNATURE"]
  )

  # ev.type ∈ "payment.succeeded" | "payment.failed" | "payment.expired" | "payment.refunded"
  status 200
end
```

```ruby
# Rails controller
class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def payhub
    body = request.raw_post
    ev = Payhub::WebhookEvent.verify(
      ENV.fetch("PAYHUB_WEBHOOK_SECRET"),
      body,
      request.headers["Hub-Signature"]
    )
    head :ok
  end
end
```

## Errors

| Class | When |
| --- | --- |
| `Payhub::Errors::AuthenticationError` | 401 |
| `Payhub::Errors::PermissionError` | 403 |
| `Payhub::Errors::NotFoundError` | 404 |
| `Payhub::Errors::IdempotencyConflictError` | 409 |
| `Payhub::Errors::ValidationError` | 422 |
| `Payhub::Errors::RateLimitedError` | 429 (`#retry_after`) |
| `Payhub::Errors::GatewayError` | 5xx + `gateway.<psp>.*` |
| `Payhub::Errors::ServerError` | other 5xx |
| `Payhub::Errors::TimeoutError` | timeout |
| `Payhub::Errors::ConnectionError` | TCP / TLS / DNS failure |
| `Payhub::Errors::DecodeError` | malformed response |
| `Payhub::MalformedHeaderError` | webhook header missing `t=`/`v1=` |
| `Payhub::TimestampOutOfToleranceError` | webhook clock skew > 300 s |
| `Payhub::InvalidSignatureError` | webhook HMAC mismatch |

## License

MIT — see `LICENSE`.
