# CarPlay entitlement request — draft

Submit at **https://developer.apple.com/contact/carplay** (signed in with the Apple Developer
account that owns the app). Apple asks for the information below; answers are drafted in English,
which is what the review team reads. Fill in the bracketed fields before sending.

| Field | Answer |
|---|---|
| App name | Mi Mazda (mzd-owner) |
| Bundle ID | `com.jeronimotech.mzdOwner` |
| Team ID | `[YOUR_TEAM_ID]` (developer.apple.com → Membership) |
| CarPlay app category | **Driving task** (`com.apple.developer.carplay-driving-task`) |
| App Store status | In development, not yet published · source: https://github.com/jeronimotech/mzd-owner |
| Countries | Colombia first, then Latin America |

## App description

Mi Mazda is a companion app for owners of Mazda vehicles (2014–2020 models without built-in
connected services). It reads the car's live status from a standard OBD-II Bluetooth LE adapter
and keeps track of maintenance.

## What the driver can do in CarPlay

All CarPlay screens use the provided templates (list, list image row, information) and update at
most every 10 seconds:

1. **Check vehicle status** — engine coolant temperature, battery/charging voltage, speed and RPM,
   with warnings when coolant temperature or charging voltage is out of range.
2. **See maintenance that is due** — oil change, tire rotation, brake fluid, mandatory insurance
   and inspection dates, highlighted when overdue or due within 1,000 km / 30 days.
3. **Check for engine trouble codes** — when the check-engine light turns on, the driver can see
   whether stored diagnostic trouble codes exist (codes are explained later on the phone, not in
   the car).

## Why these are driving tasks

Each feature relates directly to operating and maintaining the vehicle while driving: knowing if
the engine is overheating or the alternator is not charging is safety-relevant information the
2014–2020 Mazda instrument cluster does not display numerically. The app does not show media,
messaging, browsing or non-driving content in CarPlay, requires no text input, and keeps every
flow within two template levels.

## Distraction considerations

- No free text, no scrolling content beyond short lists, no video or animation.
- Detailed explanations (e.g. what a trouble code means) are only available on the phone and the
  CarPlay screen says so.
- Refresh rate limited to once every 10 seconds.

## Before submitting

- [ ] Enroll the organization in the Apple Developer Program (if not already) and use the bundle ID above.
- [ ] Attach 2–3 screenshots of the CarPlay simulator (Simulator → I/O → External Displays → CarPlay).
- [ ] After approval: enable the CarPlay capability on the App ID, regenerate the provisioning profile,
      and keep `ios/Runner/Runner.entitlements` as is.
