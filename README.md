# SmartHomeConductor

Native SwiftUI smart-home inventory, discovery, and control foundation for iPhone and Mac Catalyst.

## Current Build

- User-owned inventory with persistent manual add and delete
- Initial inventory for the Electrolux Wellbeing A5, Xiaomi Air Purifier 4 Compact, MDV split AC, Samsung Smart TV, and the listed Tapo devices
- No simulated online devices, sensor readings, events, automations, or bridge commands
- Real Bluetooth advertisement scanning with Core Bluetooth
- Real Bonjour browsing for HomeKit, Matter, HTTP, RTSP, and MQTT services
- Apple Home accessory and room import through HomeKit
- Explicit distinction between discovered, imported, reachable, and controllable devices
- Local assistant discovery command and model-specific connection guidance
- Bundled Core ML sound model with Sound Analysis microphone streaming
- Adaptive iPhone and Mac Catalyst interface with a restrained animated marble surface

See [CONNECTIVITY.md](CONNECTIVITY.md) for the device and integration matrix.

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

HomeKit import on a physical device requires a signing profile with the HomeKit capability. Bluetooth, Apple Home, microphone, and local-network access remain subject to system permission.

## Structure

- `AppStore.swift`: persistent user inventory, state, and guarded actions
- `IntegrationCore.swift`: HomeKit, Bluetooth, and Bonjour discovery
- `SoundClassifierController.swift`: Core ML and Sound Analysis stream
- `Components.swift`: black-marble visual system and interaction states
- `ContentView.swift`: adaptive iPhone menu and Mac sidebar

## Optional AI Gateway

Unknown assistant requests can be sent to `AI_GATEWAY_URL` when **Local processing only** is disabled. Keep API keys in a separately hosted gateway. Never place API tokens, Wi-Fi credentials, camera URLs, device keys, bridge secrets, or model training data in the app bundle or git history.
