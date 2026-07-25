# Conductor AI Learning Plan

Conductor should be teachable, auditable, and safe. It should not silently retrain itself from a home.

## Memory Layers

| Layer | Purpose | Storage |
| --- | --- | --- |
| Technical knowledge | Manuals, protocols, firmware notes, error codes, wiring, setup guides | Hosted vector store with source citations |
| Home memory | Room aliases, device nicknames, routines, comfort defaults | Local SwiftData records |
| User preferences | Response style, automation limits, comfort and energy preferences | Local encrypted profile, optional sync later |
| Product improvement | Accepted answers, corrections, failed searches, action outcomes | Opt-in anonymized feedback database |

## Implemented Now

- `LearnedRecord` SwiftData model for memory facts, preferences, routines, permissions, and feedback.
- Teach tab for creating, inspecting, confirming, and deleting learned records.
- Assistant commands:
  - `remember studio means upstairs office`
  - `prefer 22 C after 18:00`
  - `never turn cameras on automatically`
  - `feedback this answer helped`
- Confirmed records are included in the assistant gateway context.

## Next Engineering Milestones

1. Add encrypted-at-rest export/import for SwiftData memory.
2. Add a secure AI gateway with structured tools:
   - `search_manuals`
   - `get_device_state`
   - `propose_automation`
   - `set_device_power`
   - `run_scene`
   - `diagnose_device`
3. Add a technical document ingestion pipeline for manuals, datasheets, Matter/HomeKit/MQTT references, firmware notes, and troubleshooting trees.
4. Require citations for answers based on manuals or device documentation.
5. Add permission policies for physical actions. Read-only actions can run automatically; cameras, heating extremes, locks, alarms, and electrical loads require confirmation.
6. Build opt-in feedback capture and offline evals before changing prompts, retrieval settings, or tool policy.

## Training Rule

The product improves through retrieval, memory, tools, feedback, and offline evals. It does not continuously fine-tune from private household behavior.
