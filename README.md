# AppStoreNotifier

💧 A project built with the Vapor web framework.

## Getting Started

To build the project using the Swift Package Manager, run the following command in the terminal from the root of the project:
```bash
swift build
```

To run the project and start the server, use the following command:
```bash
swift run
```

To execute tests, use the following command:
```bash
swift test
```

## App Store notifications

Configure Postgres with either `DATABASE_URL` or these variables:

```bash
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USERNAME=vapor_username
POSTGRES_PASSWORD=vapor_password
POSTGRES_DATABASE=vapor_database
```

Run migrations before receiving notifications:

```bash
swift run AppStoreNotifier migrate
```

Docker starts with `MIGRATE_ON_START=true` by default, so the app runs pending migrations before serving traffic. Set `MIGRATE_ON_START=false` to manage migrations manually

Configure App Store Server Notification verification:

```bash
APPLE_BUNDLE_ID=com.example.app
APPLE_APP_APPLE_ID=1234567890
APPLE_ENABLE_ONLINE_CHECKS=true
```

The Apple Root CA - G3 certificate is bundled with the app. To override the bundled certificate, set `APPLE_ROOT_CERTIFICATE_PATHS` to a comma-separated list of certificate paths.

Receive App Store Server Notifications V2 at separate endpoints:

```http
POST /app-store/notifications/production
POST /app-store/notifications/sandbox
```

The request body must be the Apple payload:

```json
{
  "signedPayload": "ey..."
}
```

Notification events are stored in `app_store_notification_events`

### Read saved notifications

Set `EVENTS_API_TOKEN` to a long random secret in the runtime environment and redeploy
Generate one with `openssl rand -hex 32` and keep it private

```bash
curl 'https://YOUR_HOST/app-store/notifications/events?page=1&per=100' \
  -H "Authorization: Bearer $EVENTS_API_TOKEN"
```

The response contains `items` and `metadata` (`page`, `per`, `total`)
Fetch successive pages until all `total` records have been retrieved
Results include all saved notification types and verification states, ordered oldest first with ID as a tie-breaker
The default page size is 100 and the maximum is 250
Pages are live database reads, so avoid deleting records while traversing them

Each item includes transaction details, verification status, `mailStatus`, `mailError`, `mailAttemptedAt`, and `mailSentAt`
Raw signed and decoded payloads are omitted and successful responses use `Cache-Control: no-store`
Use HTTPS and send the token only in the Authorization header
Missing or incorrect credentials return 401; an unset or blank `EVENTS_API_TOKEN` disables access with 503
The Apple webhook POST endpoints do not require this token

For notifications to identify an account in your own system, the app encodes the positive decimal billing user ID into a zero-padded UUID. For example, user `123` becomes `00000000-0000-0000-0000-000000000123`. The notifier decodes this value and includes the billing user ID in event emails. Apple doesn't provide the customer's Apple ID or email address

## Mail

Mail is sent for every new valid notification by default. Set `MAIL_EVENT_TYPES` to a comma-separated allowlist to receive only selected notification types. `*` also means all notification types

`SMTP_SECURITY` supports `ssl`, `starttls`, `starttls-when-available`, and `none`. It defaults to `ssl` on port 465, `starttls` on port 587, and `none` on other ports for compatibility. Use `none` only on a trusted private network

```bash
SMTP_HOSTNAME=smtp.example.com
SMTP_USERNAME=app-store@example.com
SMTP_PASSWORD=secret
SMTP_FROM_NAME="App Store Notifier"
SMTP_PORT=587
SMTP_SECURITY=starttls
MAIL_TO=ops@example.com,finance@example.com
MAIL_EVENT_TYPES=REFUND,REVOKE,DID_FAIL_TO_RENEW,EXPIRED
```

`MAIL_FROM` can be set to override the sender address. Otherwise `SMTP_USERNAME` is used

Each handled webhook emits one structured `app_store_notification_request` log with the request ID, environment, notification UUID and type, duplicate status, mail status, duration, HTTP status, and sanitized error details. Successful mail delivery is also recorded on the event as `mail_status`, `mail_attempted_at`, and `mail_sent_at`. Failed deliveries are marked `failed` and retried if Apple delivers the same notification again

Test SMTP independently before testing Apple delivery:

```bash
swift run AppStoreNotifier test-email --env production
```

For App Store Server Notifications testing, configure these Version 2 URLs in App Store Connect under the app's General > App Information page:

```text
Production: https://YOUR_HOST/app-store/notifications/production
Sandbox:    https://YOUR_HOST/app-store/notifications/sandbox
```

Use an In-App Purchase API key with Apple's sandbox `Request a Test Notification` endpoint. Apple sends a signed `TEST` notification to the configured sandbox URL. Check the delivery report and service logs to confirm receipt

Mount the downloaded In-App Purchase `.p8` key and configure:

```bash
APPLE_IAP_KEY_ID=ABCDEFGHIJ
APPLE_IAP_ISSUER_ID=00000000-0000-0000-0000-000000000000
APPLE_IAP_PRIVATE_KEY_PATH=/run/secrets/SubscriptionKey_ABCDEFGHIJ.p8
```

Then request a real sandbox notification and check Apple's delivery report:

```bash
swift run AppStoreNotifier request-test-notification --environment sandbox
swift run AppStoreNotifier test-notification-status TEST_TOKEN --environment sandbox
```

Finally confirm a `TEST` notification in the service logs or inspect the saved event directly in the database

### See more

- [Vapor Website](https://vapor.codes)
- [Vapor Documentation](https://docs.vapor.codes)
- [Vapor GitHub](https://github.com/vapor)
- [Vapor Community](https://github.com/vapor-community)
