# Commercial Readiness Ledger

This ledger separates implemented product behavior from work that requires physical
hardware, vendor approval, Apple credentials, hosted infrastructure, or legal review.

Status meanings:

- **Implemented**: present in the repository and covered by an automated or reproducible check.
- **External validation**: the software boundary exists, but completion requires hardware or an account not stored in the repository.
- **Planned**: intentionally sequenced after a prerequisite.
- **Blocked**: cannot be completed without the named external action.

## Product Boundaries

| Product | Current status | Release gate |
| --- | --- | --- |
| iPhone and Mac app | Active prototype | Three real integrations, migration tests, signed beta, privacy/support publishing |
| Homeowner web dashboard | Planned | Secure gateway and account model proven with the local app |
| Installer SaaS | Planned | Real integrations, tenant isolation design, remote-command security review |

The local app must remain useful without a subscription or cloud connection. The
future cloud service may provide remote support and synchronization, but it must not
be required for ordinary local control.

## Phase 1 - Reproducible Builds

| Acceptance criterion | Status | Evidence or action |
| --- | --- | --- |
| Full Xcode selected | Implemented | `xcode-select -p` points to `/Applications/Xcode.app/Contents/Developer` |
| iPhone build and tests | Implemented | `./Scripts/manage.sh verify` |
| Mac Catalyst build | Implemented | `./Scripts/manage.sh verify` |
| Version and GitHub Release agree | Implemented | Xcode build settings plus automated `v*` tag release workflow |
| CI repeats unsigned builds | Implemented | `.github/workflows/verify.yml` |

## Phase 2 - Real Integrations

The production adapter contract requires discovery, authentication, state reads,
typed command execution, update subscription, reconnect, health checks, and
disconnect. Discovery is not authorization.

| Route | Status | External action |
| --- | --- | --- |
| Apple Home / HomeKit | External validation | Test import, reads, writes, revoked access, and network loss on the owner's home |
| Matter | External validation | Provide a commissionable Matter accessory and Apple provisioning profile |
| MQTT / Shelly | External validation | Provide broker or Shelly test endpoint and non-production credentials |
| Licensed vendor API | Blocked | Select vendor and obtain documented production API/OAuth approval |
| Tapo private/local route | Planned | Do not ship until protocol licensing and real-hardware tests are resolved |
| RF / IR bridge | Planned | Hardware design, replay limits, fingerprints, and electrical safety review |

No brand is described as fully supported until its real-device matrix passes.

## Phase 3 - Persistence and Recovery

| Acceptance criterion | Status | Evidence or action |
| --- | --- | --- |
| Learned memory in SwiftData | Implemented | `LearnedRecord` model |
| Home state in SwiftData | Implemented | Normalized home persistence models and legacy import |
| Credentials outside SwiftData | Implemented | Keychain credential boundary |
| Configuration export/import | Implemented | Versioned JSON package and round-trip tests |
| Upgrade A to B migration | External validation | Install a signed older beta, upgrade to the new beta, and compare exported state |
| Corrupt-store recovery | Implemented | Persistent-container failure falls back to an explicit in-memory mode |

## Phase 4 - Mac Quality

| Acceptance criterion | Status | Evidence or action |
| --- | --- | --- |
| Adaptive split navigation | Implemented | `NavigationSplitView` |
| Search and contextual actions | Implemented | Device search and record/rule context menus |
| Menu commands and shortcuts | Implemented | App-level navigation and operational commands |
| Separate settings and audit windows | Implemented | SwiftUI window scenes |
| Native toolbar | Implemented | Main-window operational toolbar |
| Menu-bar status item | Planned | Requires a dedicated macOS target or validated Catalyst/AppKit bridge |
| Launch at login | Planned | Add only with explicit user consent after signed beta |
| Drag-and-drop configuration import | Planned | Add after export schema stabilizes |

## Phase 5 - Safe AI

| Acceptance criterion | Status | Evidence or action |
| --- | --- | --- |
| Typed command model | Implemented | Capability and risk-aware command types |
| Read versus physical-action policy | Implemented | Deterministic command authorization policy |
| Confirmation for sensitive actions | Implemented | Policy result blocks execution until confirmed |
| Physical-action audit | Implemented | Persistent command audit records |
| AI memory cannot override safety | Implemented | Safety policy is code, not assistant context |
| Technical document retrieval with citations | Planned | Requires a deployed gateway and document store |
| Offline eval suite | Planned | Requires consented examples and versioned gateway prompts |

## Phase 6 - Installer SaaS

Status: **Planned after real integrations**.

Required domains are identity, organizations, technicians, customers, homes,
commissioning, telemetry, knowledge, remote commands, auditing, billing, and
support. Every local gateway must initiate an outbound encrypted connection.
Remote commands must be scoped, signed, short-lived, replay-resistant, and audited.

## Phase 7 - Commercial QA and Distribution

| Acceptance criterion | Status | External action |
| --- | --- | --- |
| Unsigned local archive command | Implemented | `./Scripts/archive-mac.sh unsigned` |
| Developer ID archive/export | External validation | Install valid Developer ID Application and Installer identities |
| Notarization | Blocked | Create Keychain profile `CONDUCTOR_NOTARY` |
| Universal architecture verification | Implemented in script | Run against signed exported app |
| App icon asset | Implemented | `Assets.xcassets/AppIcon.appiconset` |
| Privacy, security, terms, support drafts | Implemented | `Documentation/` |
| Public policy and support URLs | Blocked | Publish reviewed documents on an owned domain |
| TestFlight beta | Blocked | Apple Developer membership, App Store Connect record, signing profile |
| Setapp application | Planned | Apply after signed beta and real-integration reliability data |
| AppSumo | Planned | Consider only for mature installer SaaS with bounded cloud economics |

## Required Real-World Test Matrix

- Apple Silicon Mac and Intel Mac
- Current macOS and oldest supported macOS
- Current iPhone and oldest supported iOS
- Clean install and upgrade install
- Offline operation and local-network interruption
- Gateway outage and AI quota exhaustion
- Corrupt persistence and export/import recovery
- 100 devices and 500 automation events
- Denied microphone, Bluetooth, local-network, and Home permissions
- Revoked HomeKit access
- Credential expiry and unsupported device firmware

Results must identify hardware model, firmware, OS version, app version, and sanitized
diagnostics. A passing simulator build is not evidence of vendor-device compatibility.
