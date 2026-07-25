# Security Model

## Core Rules

- Local devices are never exposed directly to the public internet.
- A future gateway initiates outbound encrypted connections.
- Discovery does not imply authentication or control.
- Credentials are stored in Keychain, not SwiftData, logs, exports, or git.
- Physical commands are typed, capability-checked, policy-checked, time-bounded, and audited.
- Assistant memory cannot weaken the compiled safety policy.

## Remote Command Envelope

A future remote command must include a unique identifier, organization and home scope,
target device, typed command, issuing principal, issued time, expiry time, nonce,
policy version, and signature. The local gateway rejects expired, replayed, wrongly
scoped, unsupported, or unsigned commands.

## Sensitive Actions

Confirmation is required for cameras, locks, doors, alarms, ovens, HVAC extremes,
destructive configuration, and other safety-critical loads. Ordinary light and scene
behavior remains user-configurable. Every accepted or rejected physical command
creates an audit record.

## Diagnostics

Diagnostics may include app version, OS version, adapter health, sanitized endpoint
types, timing, and error categories. They must exclude access tokens, passwords,
camera URLs, Wi-Fi secrets, private payloads, and raw household audio.

## Vulnerability Reporting

Before public distribution, publish a monitored security contact and a coordinated
disclosure policy. Do not request secrets or private household data in a bug report.
