# AFDC Platinum - External Integrations

This document describes all external service integrations, their purpose, and how they are used in the application.

---

## Braintree (Payments)

**Gem:** `braintree ~> 2.101.0`

Braintree handles all payment processing for league registrations and pickup games.

### Customer Management

- Each user has a Braintree customer record, referenced by `user.braintree_customer_id`.
- Customer records are created on first payment.
- Payment methods (credit cards) are stored in Braintree's vault for reuse.
- `user.braintree_token` generates a client token for the Braintree JS SDK.

### Transaction Flow

1. **Client-side:** Braintree.js collects payment details and returns a nonce.
2. **Pre-authorization:** Server creates a transaction with `submit_for_settlement: false` to hold funds.
3. **Capture:** `PaymentCaptureWorker` submits the transaction for settlement asynchronously.
4. **Recording:** A `PaymentTransaction` record stores the Braintree `transaction_id`, amount, method, and service fee.

### Refunds

- Full and partial refunds are supported via the Braintree API.
- `registration.refund!(amount)` calls `Braintree::Transaction.refund`.
- Refunded amounts are tracked in `PaymentTransaction.refunded_amount`.
- Pickup registrations are auto-refunded on game cancellation.

### Custom Fields

Each transaction includes custom fields for traceability:

| Field             | Value                        |
|-------------------|------------------------------|
| `registration_id` | Registration BSON ObjectId  |
| `league_id`       | League BSON ObjectId        |
| `user_id`         | User BSON ObjectId          |

### Channel

All transactions are tagged with channel `leagues.afdc.com` for reporting in the Braintree dashboard.

---

## Twilio (SMS)

**Gem:** `twilio-ruby ~> 5.10.7`

Twilio provides SMS messaging for notifications and confirmations.

### Uses

1. **Notification method confirmation:** When a user adds a phone number as a notification method, a confirmation code is sent via SMS (`NotificationConfirmationWorker`).

2. **Game cancellation notifications:** When games are rained out, SMS notifications are sent to players who have confirmed text notification methods (`GameCancellationWorker`).

### Implementation

- SMS is sent via the `NotificationMethod#send_text` instance method.
- Phone numbers are validated to be 10 digits.
- The Twilio client is configured with account SID and auth token from environment variables.

### Inbound — Attendance Replies

The AFDC Twilio number's "A Message Comes In" webhook should be set to:

`POST https://leagues.afdc.com/attendance_prompts/sms`

Configured in the Twilio Console → Phone Numbers → (the AFDC number) → Messaging → "A message comes in" webhook URL.

The endpoint accepts standard Twilio message webhook params (`From`, `Body`, `MessageSid`, ...) and returns TwiML.

Players reply with two-digit codes (e.g. `11` = YES) provided in the outbound prompt. Free-text notes after the code are captured. See `app/controllers/attendance_prompts_controller.rb` and `lib/afdc/attendance_reply_parser.rb`.

### Required env vars

- `TEST_MONGO_HOST` (optional) — overrides the test Mongo host. Defaults to `localhost`. Set to `mongodb` when running the test suite via `docker-compose.test.yml`.

(Tokenized RSVP URLs in attendance emails use `config.action_mailer.default_url_options[:host]`, already configured in `config/environments/production.rb`.)

---

## MailChimp / Gibbon (Email Lists)

**Gem:** `gibbon ~> 3.0`

MailChimp manages the AFDC newsletter mailing list. The Gibbon gem provides the Ruby client for the MailChimp API v3.

### Uses

1. **Subscribe on registration:** When a player's registration becomes active, `MailChimpWorker` subscribes them to the newsletter list.

2. **Unsubscribe on cancellation:** When a registration is canceled, the player may be unsubscribed.

### Merge Fields

| MailChimp Field | Source              |
|-----------------|---------------------|
| `FNAME`         | `user.firstname`    |
| `LNAME`         | `user.lastname`     |

### Implementation

- All MailChimp operations are performed asynchronously via `MailChimpWorker` (Sidekiq).
- The MailChimp API key and list ID are configured via environment variables.

---

## Bugsnag (Error Monitoring)

**Gem:** `bugsnag ~> 5.1.0`

Bugsnag captures and reports application errors in production.

### Configuration

- Bugsnag is initialized in an initializer with the API key from environment variables.
- Unhandled exceptions in controllers and workers are automatically reported.
- User context (ID, email) is attached to error reports for debugging.

---

## Google Maps (Field Locations)

Google Maps is used to display field site locations and provide directions.

### Uses

1. **Field site display:** Each `FieldSite` has `latitude` and `longitude` fields. The Google Maps JavaScript API renders markers on an interactive map.

2. **Directions:** Users can click a map marker to get driving/walking directions to the field. The `map_url` and `directions` fields on `FieldSite` provide additional navigation information.

### Implementation

- The Google Maps JavaScript API is loaded in field site views.
- Field site coordinates are passed to the client-side JavaScript.
- The Maps API key is configured via environment variables.
- The JavaScript URL is versioned to ensure users get updated copies (see commit history for `fieldsite` JavaScript versioning).
