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

Optional query filters are `type`, `productId`, `transactionId`, `environment`, and `limit`

## Mail

Mail is sent only for selected notification types. Without a supported transport, matching mails are logged

```bash
MAIL_FROM=app-store@example.com
MAIL_TO=ops@example.com,finance@example.com
MAIL_EVENT_TYPES=REFUND,REVOKE,DID_FAIL_TO_RENEW,EXPIRED
MAILER_PROVIDER=mailgun
MAILGUN_API_KEY=key-example
MAILGUN_DOMAIN=mg.example.com
```

### See more

- [Vapor Website](https://vapor.codes)
- [Vapor Documentation](https://docs.vapor.codes)
- [Vapor GitHub](https://github.com/vapor)
- [Vapor Community](https://github.com/vapor-community)
