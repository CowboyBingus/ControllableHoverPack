> Release for Steam build 25480438 / EXE 1.8.46015.0. Offline checks passed; checked in live play.

Performance update v1.7: Skips window-focus system calls on frames without a hover pack and decodes game data without extra copies or allocations. Behavior is unchanged; early descent was confirmed live.

![Controllable Hover Pack](assets/banner.png)

# Controllable Hover Pack

Press Space again during hover-pack flight to descend early while preserving the pack's native landing assistance.

- **End flights early.** Vanilla hover flight runs until its automatic cutoff. Release Space after takeoff, then press it again to begin descending when you choose.
- **Native landing assistance.** The pack still slows your descent near the ground, including when you end a flight early.
- **Deliberate cancellation.** Holding the initial activation press does not cancel the flight; you must release and press again.
- **Normal duration on the next flight.** Ending one flight early does not shorten the next.

If you have rebound the Jump Pack action, use that binding instead of Space.

Release **v1.7** reduces per-frame overhead. Offline checks cover this revision; in-game frame-time validation is pending. Routine diagnostics are off by default; developers can set `CowboyBingusDiagnostics = true` before initialization to enable them.

Current version: **v1.7**, for game build **25480438**. See [changes](CHANGELOG.md) and [validation coverage](docs/MIGRATION_VALIDATION.md).
