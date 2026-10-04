# v1.8

- With a hover pack worn, each frame re-reads the pack's records where it last found them instead of locating them again: 16 memory reads instead of 41, and 8 instead of 25 without a backpack.
- A flight frame no longer reads every value a second time: 16 reads instead of 82; an early-descent press still locates the pack afresh before writing.
- With a hover pack worn but not flying, each frame skips the window-focus check, and during a flight the focus check makes two Windows calls instead of three.
- The per-frame check of a worn hover pack no longer creates Lua garbage (about 6-7 KB per frame before).
- The first early descent with each hover pack makes 5 memory-protection checks instead of 9, and still checks every location before the first write.
- The jump input's held time is decoded from its bytes, so an invalid value in memory is refused as unsupported input.
- An error raised by the game's update or another mod's now passes through unchanged, so its stack trace starts where it was raised.
- After such an error the mod restores the hover duration and pauses, then starts afresh once 60 frames in a row run without an error.
- An error in the mod itself no longer stops it at once, and each burst of errors gets one log line.
- Eight errors of either kind within about a minute of each other stop the mod for the session.
- The shutdown status keeps the first failure (`stopped after: <reason>`), and reads `restore_failed` when the shutdown restore fails.
- After the mod stops, a hover restore that keeps failing is tried on 10 spaced updates over about 8.5 seconds instead of every frame, with one log line when it gives up.
- Memory reads, protected writes and game-file checks come from Bingus Shared Runtime v1 under private names, so another mod's Windows declarations can no longer break them.
- The game-file checksums are computed once per session and shared with every mod that uses the runtime.
- The mod is now licensed under the Zero-Clause BSD license (0BSD).
- Requires Bingus Shared Loader v18 or newer.
- Measured in live play: 0.017 ms per frame in client missions (0.038 before) and 0.007 on the ship.

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
