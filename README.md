> Current local compatibility candidate for Steam build 25480438 / EXE 1.8.46015.0. Offline checks passed; live gameplay verification is pending.

Mission repair v1.6: Repairs current-build flight, ragdoll, dive and swimming checks. The production reader recognizes an airborne Hover Pack in captured mission data; installed cancel behavior still needs confirmation.

![Controllable Hover Pack](assets/banner.png)

# Controllable Hover Pack

Press Space again during hover-pack flight to descend early while preserving the pack's native landing assistance.

- **End flights early.** Vanilla hover flight runs until its automatic cutoff. Release Space after takeoff, then press it again to begin descending when you choose.
- **Native landing assistance.** The pack still slows your descent near the ground, including when you end a flight early.
- **Deliberate cancellation.** Holding the initial activation press does not cancel the flight; you must release and press again.
- **Normal duration on the next flight.** Ending one flight early does not shorten the next.

If you have rebound the Jump Pack action, use that binding instead of Space.

Release **v1.6** includes input/performance fixes. Offline checks cover this revision; in-game frame-time validation is pending. Routine diagnostics are off by default; developers can set `CowboyBingusDiagnostics = true` before initialization to enable them.

Current version: **v1.6**, for game build **25480438**. See [changes](CHANGELOG.md) and [validation coverage](docs/MIGRATION_VALIDATION.md).
