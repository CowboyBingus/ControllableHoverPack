# v1.7

- Skips the window-focus system calls on frames without a hover pack; the focus gate is unchanged whenever a pack is present.
- Decodes fields without copying the rest of each buffer, and decodes pointers without allocating.
- Behavior is unchanged; early descent was confirmed live.

# v1.6

- Refresh the game-build checks for Steam build 25480438.
- Preserve manual descent and native landing assistance.
- Offline builds and package checks pass; live gameplay validation remains pending.

# v1.5

- Update compatibility for game build 25327279.
- Restore manual hover cancellation and landing assistance.
- Correct the flight and movement checks.

# v1.3

- Disable periodic diagnostic file writes and console output by default.
- Keep startup, failure and shutdown reports available.
- Preserve hover cancellation and native landing assistance.
- Offline regression checks cover this update; live frame-time verification remains pending.

# v1.2

- Fixes manual hover cancellation on defense missions, including Evacuate High-Value Assets.
- Recovers after mission transitions and temporary player or pack-data interruptions.
- Preserves native landing assistance and normal duration on the next flight.
- Moves logs to `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs`.
- Requires Bingus Shared Loader v14 for the shared log folder.
