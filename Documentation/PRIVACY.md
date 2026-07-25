# Privacy Policy Draft

Last updated: 2026-07-25

This draft describes the intended behavior of SmartHomeConductor. It must be reviewed,
completed with the operator's legal identity and contact details, and published before
commercial distribution.

## Local Data

Device inventory, room assignments, automations, events, preferences, learned memory,
and command audits are stored on the user's device. Integration secrets belong in the
Apple Keychain and are not included in configuration exports.

## Local Permissions

The app requests Home, Bluetooth, local-network, and microphone access only for
features the user starts or enables. Denying a permission must leave unrelated local
features available.

## AI Processing

Local-only mode does not send assistant requests to a remote AI gateway. When remote
AI is enabled, the app may send the current request and a bounded home-context summary
to the configured gateway. API credentials must never be embedded in the app.

## Cameras and Audio

Camera access and audio classification are sensitive features. Audio classification is
intended to run on-device. Raw camera or microphone content must not be uploaded,
retained, or used for product training without separate explicit consent.

## Export and Deletion

Users can export their home configuration, reset local home data, inspect learned
records, and delete learned records. Keychain credentials require a separate explicit
deletion path for each integration.

## Product Improvement

Feedback collection is opt-in. Private home data must not be silently used to train
models. Consented product feedback should be minimized, anonymized where practical,
retention-limited, and separated from account identity.

## Required Before Publication

- Operator legal name and postal address
- Privacy contact email
- Exact hosted services and subprocessors
- Data-retention periods
- Account deletion procedure
- Applicable regional rights and complaint process
- Public policy URL

This document is a product draft, not legal advice.
