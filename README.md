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

## Commands

```bash
./Scripts/manage.sh list
./Scripts/manage.sh build
./Scripts/manage.sh open
./Scripts/manage.sh git-init
```

## Git Recommendation

Use this app folder as its own repository. Keep `main` protected, develop with short-lived feature branches, and use forks for outside collaborators or risky hardware integrations. Do not commit Wi-Fi credentials, camera URLs, API tokens, device keys, model datasets, or local bridge secrets.
