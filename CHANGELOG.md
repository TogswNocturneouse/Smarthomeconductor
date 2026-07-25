# Changelog

All notable changes to SmartHomeConductor are documented here.

## 0.3.0 - 2026-07-25

### Added

- Normalized SwiftData persistence for homes, rooms, devices, capabilities, states,
  automations, events, preferences, integrations, bridge definitions, and command audits.
- Legacy `UserDefaults` import with explicit in-memory recovery mode.
- Versioned home configuration export and import.
- Typed command authorization with capability checks, confirmation policy, and audit history.
- Keychain-only integration credential storage boundary.
- Full production adapter lifecycle contract.
- Mac menu commands, keyboard shortcuts, operational toolbar, settings window, and command-audit window.
- App icon, privacy manifest, commercial-readiness ledger, policy drafts, CI verification, and Mac archive tooling.

### Changed

- Lower the app deployment target from iOS 26.0 to iOS 18.0.
- Stop bridge commands and offline assistant requests from claiming physical execution.
- Label imports, bundled models, and adapter scaffolds according to their actual state.

## 0.2.2 - 2026-07-25

### Changed

- Align the app's Xcode marketing version and build number with GitHub releases.
- Add automatic GitHub Release creation for every pushed `v*` tag.
- Add a maintained changelog for release history.

## 0.2.1 - 2026-07-25

### Added

- Restrained visuals setting for lower GPU use and calmer ambient effects.
- Customer-friendly subscription and monetization guidance.

### Changed

- Reduced background animation frequency, glow, blur, and decorative rendering.
- Improved compact navigation, Teach Conductor controls, and learned-record deletion.

## 0.2.0 - 2026-07-25

### Added

- User device inventory with manual add and delete.
- Bluetooth, Bonjour, and authorized HomeKit discovery foundations.
- SwiftData-backed teachable memory, preferences, permissions, and feedback.
- Teach Conductor interface and assistant memory commands.
- Connectivity, AI learning, release, marketing, and monetization documentation.

### Changed

- Replaced demo control behavior with explicit disconnected-device handling.
- Rebuilt the interface around a dark, restrained glass and black-marble design.
- Expanded assistant safety, device knowledge, and contextual grounding.
