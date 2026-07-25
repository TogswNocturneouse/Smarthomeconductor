# Beta Onboarding

## Before Installation

The tester receives:

- Supported iOS and macOS versions
- App version and build number
- Supported integration and firmware matrix
- Privacy policy, support contact, and known limitations
- Clear notice that the beta is not a life-safety or security-alarm system

## First Run

1. Confirm the app opens without requiring a cloud account.
2. Review the existing device inventory and remove devices the tester does not own.
3. Add owned devices manually or start discovery.
4. Grant only the Home, Bluetooth, local-network, or microphone permissions needed
   for the selected test.
5. Import Apple Home only if the tester agrees to expose that home database to the app.
6. Keep **Local processing only** enabled unless the gateway test is explicitly in scope.
7. Review **Allow assistant light control** before testing assistant commands.

## Safety Check

Before physical-command testing:

- Confirm the target device and room.
- Confirm the device has a validated authenticated adapter.
- Verify the command audit window records rejected and accepted decisions.
- Keep manual manufacturer controls available.
- Do not test locks, alarms, doors, ovens, or unsafe HVAC extremes in an occupied home.

## Recovery Check

1. Export the home configuration.
2. Confirm the export contains no credential values.
3. Import the file on the same test build.
4. Confirm devices, rules, preferences, and audits match.
5. Do not reset the home until the export has been verified.

## Feedback Package

Include app version, OS version, device model, firmware, connection route, failure time,
and sanitized audit detail. Never include passwords, tokens, Wi-Fi secrets, camera
URLs, or raw household audio.
