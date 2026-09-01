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

Notification events are stored in `app_store_notification_events` and can be inspected with:

```http
GET /app-store/notifications/events
GET /app-store/notifications/events/{notificationUUID}
```

Optional query filters are `type`, `productId`, `transactionId`, `environment`, `verificationStatus`, `mailStatus`, and `limit`. Responses intentionally omit raw signed and decoded payloads

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

Use an In-App Purchase API key with Apple's sandbox `Request a Test Notification` endpoint. Apple sends a signed `TEST` notification to the configured sandbox URL. The successful result appears in the events endpoint:

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

Finally inspect the event saved by this service:

```http
GET /app-store/notifications/events?type=TEST
```

### See more

- [Vapor Website](https://vapor.codes)
- [Vapor Documentation](https://docs.vapor.codes)
- [Vapor GitHub](https://github.com/vapor)
- [Vapor Community](https://github.com/vapor-community)
