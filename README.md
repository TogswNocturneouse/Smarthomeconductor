# SmartHomeConductor

Native SwiftUI smart-home inventory, discovery, safety, and orchestration foundation
for iPhone and Mac Catalyst.

## Current Build

- User-owned inventory stored in normalized SwiftData records
- Initial inventory for the Electrolux Wellbeing A5, Xiaomi Air Purifier 4 Compact, MDV split AC, Samsung Smart TV, and the listed Tapo devices
- No simulated online devices, sensor readings, events, automations, or bridge commands
- Real Bluetooth advertisement scanning with Core Bluetooth
- Real Bonjour browsing for HomeKit, Matter, Shelly, HTTP, RTSP, and MQTT services
- Apple Home accessory and room import through HomeKit
- Authenticated Home Assistant connection with Keychain token storage, live entity import, launch refresh, typed commands, and confirmed state reads
- Explicit distinction between discovered, imported, reachable, and physically confirmed control
- Typed command authorization, confirmation rules, and persistent audit records
- Versioned home configuration export and import; credentials are excluded
- Keychain-only integration credential boundary
- Local assistant discovery command and model-specific connection guidance
- Bundled Core ML sound model with Sound Analysis microphone streaming
- Adaptive iPhone and Mac Catalyst interface with application menu commands, keyboard shortcuts, and separate settings and audit windows
- Automated GitHub verification and Release creation
- App icon and privacy manifest

Direct vendor adapters are not advertised as complete. Home Assistant is the first
implemented command transport; imported supported entities can be controlled and the
result is read back before Conductor reports success. Physical brand compatibility still
requires validation against the owner's device model and firmware.

See [CONNECTIVITY.md](CONNECTIVITY.md) for the device and integration matrix.
See [Documentation/COMMERCIAL_READINESS.md](Documentation/COMMERCIAL_READINESS.md)
for release gates and external actions.

## Run

No package download is required.

```bash
./Scripts/manage.sh verify
./Scripts/manage.sh run-ios
./Scripts/manage.sh run-mac
```

Use a different installed Simulator with:

```bash
CONDUCTOR_SIMULATOR="iPhone 17 Pro" ./Scripts/manage.sh run-ios
```

Open the project in Xcode:

```bash
./Scripts/manage.sh open
```

Create an unsigned universal Mac Catalyst archive:

```bash
./Scripts/archive-mac.sh unsigned
```

Signed and notarized modes require the Apple identities and Keychain profile documented
in the commercial-readiness ledger.

HomeKit import on a physical device requires a signing profile with the HomeKit capability. Bluetooth, Apple Home, microphone, and local-network access remain subject to system permission.

## Structure

- `HomePersistence.swift`: SwiftData home schema, legacy migration, and export package
- `CommandSafety.swift`: typed commands, risk policy, confirmations, and audits
- `CredentialStore.swift`: Keychain credential boundary
- `AppStore.swift`: observable home state and guarded actions
- `IntegrationCore.swift`: production adapter lifecycle plus HomeKit, Bluetooth, and Bonjour discovery
- `HomeAssistantIntegration.swift`: authenticated REST import and confirmed command transport
- `SoundClassifierController.swift`: Core ML and Sound Analysis stream
- `Components.swift`: black-marble visual system and interaction states
- `ContentView.swift`: adaptive iPhone menu, Mac sidebar, and operational toolbar
- `AppNavigation.swift`: app menu commands and keyboard shortcuts

## Optional AI Gateway

Unknown assistant requests can be sent to `AI_GATEWAY_URL` when **Local processing only** is disabled. Keep API keys in a separately hosted gateway. Never place API tokens, Wi-Fi credentials, camera URLs, device keys, bridge secrets, or model training data in the app bundle or git history.
