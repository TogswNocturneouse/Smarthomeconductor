# Support Runbook

## Customer Information to Request

- App version and build number
- iOS or macOS version
- Device model and firmware
- Connection route
- Time of failure and sanitized diagnostic identifier
- Whether local-network, Bluetooth, Home, or microphone permission changed

Never request passwords, access tokens, Wi-Fi credentials, camera URLs, or raw
Keychain exports.

## First Response Order

1. Confirm the device is advertised as supported.
2. Check permission and adapter health.
3. Check local-network reachability without requesting secrets.
4. Confirm firmware compatibility.
5. Reconnect the adapter without deleting the home.
6. Export the configuration before any reset.
7. Escalate with sanitized logs and the command audit identifier.

## Service Targets for a Paid Beta

- Security or cross-home isolation issue: immediate suspension and investigation
- Data loss or command safety issue: same business day
- Integration outage: one business day
- General question: two business days

Public support email, status page, refund rules, and supported languages remain
required before accepting payment.
