# SmartHomeConductor

Native SwiftUI iOS app for the Conductor smart-home interface.

## First Scope

- Normal lights
- Dimmer lights
- Multicolor lights
- Temperature and humidity sensors
- Light sensors
- IoT smart hub / bridge
- Smart TV with smart-hub behavior
- Wi-Fi smart cameras
- Smart purifier
- Smart AC-type air conditioner

## Architecture Direction

- SwiftUI for iPhone-first interface
- Capability-based device model
- Adapter layer for HomeKit, Matter, MQTT, local Wi-Fi, Bluetooth, IR, RF and vendor APIs
- Automation rules first, adaptive intelligence later
- Local-first classifier path with Core ML and Sound Analysis
- OpenAI Responses API through a separately hosted gateway; no API keys in the app

## AI Assistant

The Assistant tab sends recent conversation and a compact snapshot of device
state to the Home Conductor AI gateway. For local Simulator development, start
the gateway and keep `AI_GATEWAY_URL` in `SmartHomeConductor/Info.plist` set to:

```text
http://127.0.0.1:8787/api/chat
```

For a physical iPhone or production build, change that value to the deployed
HTTPS gateway URL. Never put `OPENAI_API_KEY` in this repository, an xcconfig,
the Info.plist, or the iOS app bundle.

## Commands

```bash
./Scripts/manage.sh list
./Scripts/manage.sh build
./Scripts/manage.sh open
./Scripts/manage.sh git-init
```

## Git Recommendation

Use this app folder as its own repository. Keep `main` protected, develop with short-lived feature branches, and use forks for outside collaborators or risky hardware integrations. Do not commit Wi-Fi credentials, camera URLs, API tokens, device keys, model datasets, or local bridge secrets.
