# Changelog

All notable changes to SmartHomeConductor are documented here.

## 0.3.4 - 2026-07-25

### Fixed

- Fix Mac Catalyst sidebar navigation so category changes replace the full content view after integration sheets are opened.
- Replace fragile documentation links with visible URL rows, explicit Open and Copy actions, and copied-URL fallback feedback.
- Add the Mac network-client entitlement needed for connection-route testing.
- Force the Mac runner to close stale installed instances before launching the latest DerivedData build.

## 0.3.3 - 2026-07-25

### Fixed

- Route assistant device commands through Home Assistant with REST confirmation instead of local state mutation.
- Merge imported Home Assistant entities into matching inventory records instead of creating duplicate devices.
- Preserve command-audit records when assistant commands are refused because a device is offline or lacks a writable adapter.
- Remove the unused starter Objective-C test template from the repository.
- Replace remaining lab-style copy in production UI with product-ready connection language.

## 0.3.2 - 2026-07-25

### Changed

- Reworked the visual system into a calmer black-marble moonlight style with lower glow, tighter borders, and quieter ambient movement.
- Put Home Assistant first in the integration registry because it is the current working command route.
- Show a direct first-connection panel on the dashboard when no live devices are connected.
- Replace disabled-looking controls on unconnected inventory devices with specific connection guidance.

### Fixed

- Stop authenticated-looking manual or imported devices from faking local state changes when no writable transport exists.
- Prevent Apple Home imports from being marked online until a writable adapter can confirm commands.
- Stop scenes from mutating local device state without a scene-capable transport.

## 0.3.1 - 2026-07-25

### Added

- Authenticated Home Assistant REST connection for local or HTTPS endpoints.
- Keychain-backed long-lived token storage and automatic launch refresh.
- Live entity import for lights, switches, sensors, fans, climate, cameras, and media players.
- Typed Home Assistant power, brightness, color, fan, and climate commands with state read-back.
- Tappable Tapo compatibility, H100 Matter Bridge, camera RTSP, Home Assistant token, and installation links.

### Fixed

- Stop repeatedly telling users to enable Tapo Third-Party Compatibility.
- Replace generic Tapo discovery advice with model-specific connection routes.
- Prevent camera metadata connections from being labeled as live video.
- Send slider commands only after editing ends to avoid flooding local devices.
- Force Catalyst destination replacement so navigation does not retain stale page content.

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
