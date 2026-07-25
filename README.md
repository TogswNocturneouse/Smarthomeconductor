# SmartHomeConductor

Native SwiftUI smart-home control surface for iPhone and Mac Catalyst.

## Working Demo

- Persistent environmental summary with temperature, humidity, light, AQI, and classifier status
- Shared device state for lights, sensors, hubs, TV, cameras, purifier, and AC
- Power, dimmer, color swatches, fan speed, climate mode, media, camera, and hub controls
- Arrive, Focus, Air care, and All off scenes
- Add, toggle, run, and delete automation rules
- TP-Link/Tapo, MDV/Midea, Xiaomi, Electrolux, Samsung, and Shelly adapter registry
- Runnable RF, IR, and MQTT command simulation
- Bundled custom Core ML sound model with Sound Analysis microphone streaming
- Local assistant commands with an optional external AI gateway
- UserDefaults persistence and resettable demo state

Vendor and hardware operations currently run through isolated preview adapters. Real device access requires the matching account credentials, local network endpoints, or paired RF/IR bridge hardware; those secrets do not belong in this repository.

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

## Structure

- `AppStore.swift`: persistent home state and executable actions
- `IntegrationCore.swift`: extensible brand adapter boundary
- `SoundClassifierController.swift`: Core ML and Sound Analysis stream
- `Components.swift`: dark glass design and interaction states
- `ContentView.swift`: adaptive iPhone menu and Mac sidebar

## Optional AI Gateway

Unknown assistant requests can be sent to `AI_GATEWAY_URL` when **Local processing only** is disabled. Keep API keys in a separately hosted gateway. Never place API tokens, Wi-Fi credentials, camera URLs, device keys, bridge secrets, or model training data in the app bundle or git history.
