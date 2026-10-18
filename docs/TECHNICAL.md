# Controllable Hover Pack: implementation and evidence

Release v1.8.1 for Steam build 25480438, EXE 1.8.46015.0. Requires Bingus Shared Loader v18 or newer (v19 is current); the module's own load check accepts loader-v11 / API 1 or newer. The first release (v1, 2026-09-16) targeted Steam build 24826606; native function addresses below marked as from that build come from its analysis and are not called by the mod.

## v1.1 mission-transition correction (internal QA)

Players reported that cancellation worked during the first mission and then reverted to vanilla behavior. No affected-player logs were available, so the exact live trigger remains unconfirmed. Internal regressions reproduced two permanent-disable paths in v1: a transient avatar/pack registry mismatch escaped the read-only snapshot into the loader's terminal error handler, and an unavailable settings record during restoration did the same. Restoring valid data did not restart cancellation because the installed hook retained `stopped=true`.

Snapshot and preflight inspection failures now reject that update without writing, clear pending input edges, and allow a fresh validated attempt. Restoration inspection failures retain the identity lease and defer new cancellation until cleanup can finish or the original manager/entity is proven gone. Mutation/rollback failures, original-update failures, and shutdown retain their terminal behavior. Native descent, landing assistance, duration values and pack flags are unchanged.

The regression suite keeps the production update hook installed across first-flight cancellation, invalid avatar/pack registries, null equipment pointers, removed local players, ship return, replaced pack generations and subsequent flights. It also covers persistent invalid data without writes, a restoration read failure followed by recovery, manager replacement without stale writes, and cancellation in the next mission after deferred cleanup. Both transition regressions failed against v1 before the fix. Existing input, native landing predicate, per-pack isolation, rollback and loader failure tests remain required.

Diagnostic logs retain `last_snapshot_error`, `last_settings_error` and `last_restore_error`, with corresponding wait counters, so later healthy frames do not erase the last read failure. The v1.1 test package is marked `runtime_verified=false`. In-game acceptance still requires two consecutive missions without restarting: cancel and land in each, verify recharge and normal next-flight duration, then repeat after equipment replacement or reinforcement. Disable the Megapack during standalone QA because its bundled v1 otherwise may win resource selection.

## Cause established by the live comparison

The user reported v0.1 cancelled hover but lost the native slow landing. A 120-second VM_READ capture recorded 6,768 samples of normal expiry and manual cancellation with v0.1 installed. Representative transitions, relative to recording start:

| Time (s) | Pack state (five bytes) | Airborne time (s) | Meaning |
| --- | --- | --- | --- |
| 0.000 | 01 00 01 00 01 | 3.571 | Normal powered hover |
| 2.453 | 01 00 01 00 00 | 6.018 | Natural duration expires; pack stays active |
| 3.338 | 01 01 01 00 01 | 6.914 | Native landing assistance re-enables lift |
| 4.199 | 00 00 01 00 00 | 7.778 | Native final shutdown |
| 14.019 | 01 00 01 00 01 | 0.019 | Later flight starts |
| 14.372 | 01 00 01 00 01 | 0.364 | Activation input released |
| 14.850 | 00 00 01 00 00 | 0.845 | v0.1 repress fully shuts down pack |

Another natural flight repeated expiry at airborne 6.028 seconds and landing assistance at 6.681 seconds. This establishes why the old `9a87c0(manager, pack, 0, 0)` call was wrong: it clears active state and associated avatar/movement state, preventing later braking. v0.2 removes that call entirely.

## Narrow duration change

On build 24826606, the native physics routine `game.dll+0x9a9b30` gets the effective component through `0x509180` (the mod calls neither). With hover duration at component +0x9c positive, its lift predicate is:

```
desired_lift = duration > airborne_time || landing_assist_active
```

A zero or negative duration instead selects hold-to-hover behavior, so zero must not be used for cancellation. v0.2 temporarily sets the individual pack's duration to exactly 1/1024 second. The next engine update reaches the same expired-duration branch as natural timeout. Landing state remains available and overrides that duration when the engine's own near-ground test succeeds.

The mod restores the original four duration bytes after active flight ends, on equipment/context change, at shutdown, and on the update after an update below it raised (that error itself passes through unchanged). The update chain comes from the runtime's update guard (`src/bingus_runtime.lua`, see below): after such an error the mod pauses and starts afresh (the input policy forgets the flight) once the updates below have returned on 60 frames in a row. 8 such errors, 8 of its own errors in a burst, or a restore that cannot finish when it pauses stop it; after a stop a held lease is tried again on the 1st, 2nd, 4th ... 512th update after it (10 attempts over about 8.5 s at 60 FPS, whether an attempt raises or keeps the lease; one log line names the last reason when they end) and once more at shutdown, where a lease still held reads `restore_failed`. Restoration resolves the pack and both maps again, allowing native array relocation/compaction. It compares resource, entity ID, unit and generation, and restores only while the duration still equals the value it wrote. Later edits by the engine or another mod take precedence. A transient cleanup failure retains the lease for retry; unsupported structures stop new cancellations.

## Per-pack storage

| Build 25480438 layout (read by the mod) | Purpose |
| --- | --- |
| `game.dll+0x33266a0` | Mission state: +8 active flag, +0x40 mission type (1-7 accepted). |
| `game.dll+0x3326468` | Player manager: +0x84 player counts, +0xe8 local player, +0x3a8 local unit. |
| `game.dll+0x346bf98` | Entity owner: +0xf22ec8 entity map, +0xf32f18 24-byte entity records, +0xf12cb8 shared jump-pack resource table (six 16-byte hash/index entries, then 280-byte components at +0x60). |
| `game.dll+0x3326d20` | Avatar manager: +0xf8 map, +0x6c count, +0x110 slots; movement flags at +0x53d900 + index*0x1238 + 0xf80; jump input at +0x150 + index*0xa7aec + 0x1b68 + 15*32. |
| `game.dll+0x3326738` | Equipment registry: +40 map, +64 identity array, +80 48-byte rows (backpack ID at +12). |
| `game.dll+0x3326dc0` | Attachment registry: +32 map, +64 48-byte rows (holder at +4). |
| `game.dll+0x3326bb8` | Jump-pack manager. Total registered count +0x0c; active prefix +0x10; locally simulated prefix +0x14 (inside active prefix). |
| Manager +0x20 / +0x38 | Entity-to-registry-index map / entity-pointer array. |
| Manager +0x48 / +0x50 | 76-byte runtime array (not read) / five-byte state array. State bytes +0 active, +1 landing assist, +4 lift. |
| Manager +0x60 / +0x80 | Entity-to-override-index / override-index-to-entity maps. |
| Manager +4 / +0x98 / +0xa0 | Override capacity / count / pointer to 280-byte component records. |

| Build 24826606 analysis (not called by the mod) | Purpose |
| --- | --- |
| `game.dll+0x509180` | Effective component getter: per-entity override first, shared resource fallback. |
| `game.dll+0x9adcd0` | Native pack destruction removes both override map entries, compacts the array and decrements its count. |
| `game.dll+0x602d20` | Native player routine that accepts mission types 1 through 7. |

A live read confirmed capacity 32, count zero, initialized forward/reverse maps and the hover component's six-second duration. The jump-pack modifier stub does not create an override, unlike the avatar helper used by ConsistentVaulting. Therefore the mod copies the current shared component into an existing free native slot and publishes its reverse map, count and forward map. It checks every destination before writing any (one protection query each, none again when writing) and rolls back partial creation failures. There is no allocation or native function invocation. A restored copy stays engine-owned until pack destruction; only its duration differs during cancellation. Existing overrides are reused without touching their other fields.

All destinations must be committed, private, already read/write data. No protection changes or executable writes are allowed. Shared settings are read only, so other players' packs keep their duration. The general airborne timer, velocity, fuel, cooldown and pack-state flags are never written by this mod; the game performs its normal physics, replication and final shutdown.

## Input and identity guards

The reader follows the player manager's local unit through the entity-owner map and avatar registry. It resolves the equipped backpack, checks hover resource `5ec80f4f1cdb66cf` and local ownership, then independently verifies the attachment's holder. Local avatar index zero is never assumed. It keeps where it found each record: later frames read the avatar, equipment, jump-pack and attachment records at those addresses, and the registry slots and array pointers that lead to them (16 reads with a hover pack instead of 41), and locate everything again from the registry roots whenever any of these differ.

On build 24826606, input helper `0x57fb00` maps pair `(2,15)` to processed input slot 15. The held duration is at +8 in its 32-byte record. Cancellation requires release followed by a fresh press during powered hover, once per flight. Initial hold, ordinary jump packs, grounded movement, native landing assistance, ragdoll, swimming and focus loss cannot issue cancellation. The cancellation lease survives falling/landing and focus loss, preventing a second request during braking. Before requesting the duration change, the press locates the pack afresh from the registry roots, which must find the same pack in the same flight with the jump held; the settings writer then rereads its own guards before writing. They are consistency checks, not synchronization primitives.

## Shared runtime

The mod vendors Bingus Shared Runtime v1, three files kept byte-identical to the canonical copies: `src/bingus_runtime.lua` (the core: the update guard and the session table every copy shares), `src/bingus_memory.lua` (the read side: reads, page checks, module hashes and the clock) and `src/bingus_write.lua` (the write side: writes checked right before they land). The build embeds all three; the loader takes the core for its guard, and `src/windows_api.lua` takes the read side extended by the write side. The runtime declares every Windows function under private, versioned names (`bingus_memory1_*`, `bingus_write1_*`), so another mod's declarations cannot change them, and it hashes each game module's file at most once per session for every mod that asks (`BingusRuntime.hashes`); the build check uses that cache. Its clock (`time()`, seconds from the performance counter) allocates nothing. The adapter adds reads at plain-number addresses into the snapshot's buffer, pointers as numbers, the 280-byte write limit, writes to destinations the caller has just checked, and the focus check.

## Per-frame cost

Calls per update through the installed hook, as the budget tests pin them (`tests/frame_budget.lua` in `test_snapshot.lua` and `test_settings.lua`). In game a read (ReadProcessMemory) costs about 1-2 us and a protection query (VirtualQuery, right before every write) about 0.29 ms. The other Windows calls (the focus check's two, WriteProcessMemory, and the clock's QueryPerformanceCounter, read for a status line, or on every update when diagnostics are enabled) and the Lua around them are unmeasured in game.

Between flights an idle gate (`M.idle` in `src/hover_data.lua`, called first in the loader's update) answers updates after a full check that found nothing to do, while no cancellation is held: 59 updates outside a mission, 29 in a mission. With a hover pack worn it reads only the pack's state row; an active state or a failed read ends the wait and runs the full check on the same update. A mission start is therefore seen up to 59 updates late (during the drop) and a hover pack picked up up to 29 updates late; the window counts updates, never the clock. `tests/test_idle_gate.lua` compares the gated mod with v1.8 frame by frame.

| Path | Calls per update | In game |
| --- | --- | --- |
| Outside a mission | 2 reads on every 60th update, none on the 59 between | about 2-4 us per 60 updates |
| No player yet, no backpack, another backpack, or a hover pack not owned or not attached (after the first frame in a mission) | 8-13 reads on every 30th update (8 without a backpack), none on the 29 between | about 8-26 us per 30 updates |
| Hover pack worn, not flying | 1 read (the pack's 5-byte state row) on 29 of every 30 updates, 16 reads on the 30th (41 on the first frame in a mission or after the layout changed) | about 1-2 us, plus 16-32 us per 30 updates |
| Native descent | 16 reads | about 16-32 us |
| Flight | 16 reads, one focus check (17 reads on the update the flight starts) | about 16-32 us, plus the focus check (unmeasured) |
| Early-descent press, first with a pack | 126 reads, 5 queries, 5 writes, two focus checks | about 1.45 ms in queries, once per pack |
| Early-descent press, later | 103 reads, 1 query, 1 write, two focus checks | about 0.29 ms in queries |
| Landing after an early descent (restore) | 47 reads, 1 query, 1 write | about 0.29 ms in queries, once per flight |
| Pause after an update error below | with a cancellation held: 31 reads, 1 query, 1 write and a status line; none without one | about 0.29 ms in queries, once per such error |
| Paused, or stopped | none | none |
| Stopped with a lease it cannot restore | an inspection (10 reads where the settings map is refused) on the 1st, 2nd, 4th ... 512th update after the stop, then one status line; none afterwards | 10 attempts in about 8.5 s at 60 FPS |
| Update pass-through above the guard, every update | one boolean test and a tail call; after a stop with a lease, an update counter for up to 512 updates | unmeasured in game. Reason: restoring the hover duration after a stop, since the guard runs nothing of a stopped mod |
| Update guard (`bingus_runtime.lua`) | a few boolean tests and stores, two counters and three small Lua calls around the work, which runs under pcall | unmeasured in game |

## Validation and remaining acceptance

The v1.2 candidate also corrects mission filtering. On build 24826606, the native player routine at `game.dll+0x602d20` accepted mission type values 1 through 7 when the active flag is nonzero. A read-only capture during Evacuate High-Value Assets showed type 2; the old exact-type-1 gate rejected every otherwise valid snapshot. Regression coverage exercises all seven types, inactive and unsupported modes, repeated mission transitions, cancellation and restoration. Replaying a captured type-2 flight against Lua-table memory permits cancellation and restores the original per-pack settings; it does not prove live landing behavior.

Transient snapshot and preflight reads now wait and retry through the existing update hook. A pending restoration remains owned until it can be checked again. Mutation and rollback failures retain terminal handling. Status logs include snapshot waits, restoration waits and the current valid mission type in the shared log folder. These changes still require consecutive-mission in-game QA.

The build runs focused checks for input edges; exact pack/holder identity; local index one; multiplayer prefix ordering; descent and landing exclusion; native lift predicate; per-pack isolation; next-flight restoration; relocation; later edits; recycled IDs; partial-write rollback; callback return values/failures/cleanup; the compiled module's embedded runtime (`tests/test_module.lua`); package identity; bytecode mode; dependencies; privacy and hashes.

The production v0.2 snapshot and settings readers also resolved the running game's local pack and override storage through a VM_READ adapter. Replaying create/cancel/restore against those captured bytes completed six writes to a Lua table and restored the original 280-byte record. This is offline mutation proof, not a native gameplay test.

The research observer never wrote to or injected into the game. Raw recordings, disassembly and read-only tools stay in ignored `artifacts/hover-pack/`. The maintainer confirmed manual cancellation and native landing assistance working before the v1 release. Additional coverage can check: cancel from height, confirm near-ground braking and the next normal-duration flight, then verify recharge, equipment replacement, death/reinforcement, mission exit and host/joined-client behavior. Logs alone do not prove a successful landing.
