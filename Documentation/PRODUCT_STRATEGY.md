# Product Strategy

## SmartHomeConductor App

Buyer: homeowners and power users.

Purpose: private local inventory, device health, scenes, environmental summaries,
safe assistance, and automation for one home.

Distribution sequence:

1. Signed TestFlight and direct beta.
2. Mac App Store after real integrations and migration QA.
3. Setapp after the Mac application is stable and adapted to Setapp policy.
4. Direct notarized Mac distribution only when support and updating are operational.

## Homeowner Web Dashboard

Buyer: homeowners who need browser access or an installer-supported home.

Purpose: inspect and configure a home through a secure browser session. It is not a
direct internet tunnel to local devices. The local gateway makes the outbound
connection and remains the authority for physical commands.

Build only after the local gateway, identity model, and remote-command envelope are
proven.

## Installer SaaS

Buyer: installation companies and support teams.

Purpose: manage organizations, technicians, customers, homes, commissioning,
templates, diagnostics, knowledge, audit trails, billing, and support.

The minimum permission roles are owner, technician, support, and read-only customer.
Tenant isolation and command authorization are release-blocking security properties,
not optional administration features.

## Monetization Rules

- Keep inventory, export/delete, privacy settings, and local safety controls free.
- Do not charge customers to recover from a broken account connection.
- Sell a brand integration only after its advertised models and firmware are tested.
- Price cloud operation by sustainable capacity such as homes, devices, storage, or
  bounded AI usage.
- Do not promise unlimited lifetime AI, telemetry, or support.
- Make cancellation, downgrade, data export, and account deletion obvious.
