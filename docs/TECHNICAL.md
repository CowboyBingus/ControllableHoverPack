# Controllable Hover Pack: implementation and evidence

Release v1, 2026-09-16. Steam build 24826606, EXE 1.8.45317.0. Separately built module registered with Bingus Shared Loader v11 / API 1.

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

The native physics routine `game.dll+0x9a9b30` gets the effective component through `0x509180`. With hover duration at component +0x9c positive, its lift predicate is:

```
desired_lift = duration > airborne_time || landing_assist_active
```

A zero or negative duration instead selects hold-to-hover behavior, so zero must not be used for cancellation. v0.2 temporarily sets the individual pack's duration to exactly 1/1024 second. The next engine update reaches the same expired-duration branch as natural timeout. Landing state remains available and overrides that duration when the engine's own near-ground test succeeds.

The mod restores the original four duration bytes after active flight ends, on equipment/context change, shutdown or a caught update failure. Restoration resolves the pack and both maps again, allowing native array relocation/compaction. It compares resource, entity ID, unit and generation, and restores only while the duration still equals the value it wrote. Later edits by the engine or another mod take precedence. A transient cleanup failure retains the lease for retry; unsupported structures stop new cancellations.

## Per-pack storage

| Current-build layout | Purpose |
| --- | --- |
| `game.dll+0x276c8d0` | Jump-pack manager. Total registered count +0x0c; active prefix +0x10; locally simulated prefix +0x14 (inside active prefix). |
| Manager +0x20 / +0x38 | Entity-to-registry-index map / entity-pointer array. |
| Manager +0x48 / +0x50 | 76-byte runtime array / five-byte state array. State bytes +0 active, +1 landing assist, +4 lift. |
| Manager +0x60 / +0x80 | Entity-to-override-index / override-index-to-entity maps. |
| Manager +4 / +0x98 / +0xa0 | Override capacity / count / pointer to 280-byte component records. |
| Entity owner +0xf11890 | Shared jump-pack resource table: six 16-byte hash/index entries, followed by 280-byte components at +0x60. |
| `game.dll+0x509180` | Effective component getter: per-entity override first, shared resource fallback. |
| `game.dll+0x9adcd0` | Native pack destruction removes both override map entries, compacts the array and decrements its count. |

A live read confirmed capacity 32, count zero, initialized forward/reverse maps and the hover component's six-second duration. The jump-pack modifier stub does not create an override, unlike the avatar helper used by ConsistentVaulting. Therefore the mod copies the current shared component into an existing free native slot and publishes its reverse map, count and forward map. It prevalidates all destinations and rolls back partial creation failures. There is no allocation or native function invocation. A restored copy stays engine-owned until pack destruction; only its duration differs during cancellation. Existing overrides are reused without touching their other fields.

All destinations must be committed, private, already read/write data. No protection changes or executable writes are allowed. Shared settings are read only, so other players' packs keep their duration. The general airborne timer, velocity, fuel, cooldown and pack-state flags are never written by this mod; the game performs its normal physics, replication and final shutdown.

## Input and identity guards

The reader follows the player manager's local unit through the entity-owner map and avatar registry. It resolves the equipped backpack, checks hover resource `5ec80f4f1cdb66cf` and local ownership, then independently verifies the attachment's holder. Local avatar index zero is never assumed.

Input helper `0x57fb00` maps pair `(2,15)` to processed input slot 15. The held duration is at +8 in its 32-byte record. Cancellation requires release followed by a fresh press during powered hover, once per flight. Initial hold, ordinary jump packs, grounded movement, native landing assistance, ragdoll, swimming and focus loss cannot issue cancellation. The cancellation lease survives falling/landing and focus loss, preventing a second request during braking. Guards recheck relevant identity, attachment, input and flags immediately before requesting the duration change. They are consistency checks, not synchronization primitives.

## Validation and remaining acceptance

The v1.2 candidate also corrects mission filtering. The supported game's native player routine at `game.dll+0x602d20` accepts mission type values 1 through 7 when the active flag is nonzero. A read-only capture during Evacuate High-Value Assets showed type 2; the old exact-type-1 gate rejected every otherwise valid snapshot. Regression coverage exercises all seven types, inactive and unsupported modes, repeated mission transitions, cancellation and restoration. Replaying a captured type-2 flight against Lua-table memory permits cancellation and restores the original per-pack settings; it does not prove live landing behavior.

Transient snapshot and preflight reads now wait and retry through the existing update hook. A pending restoration remains owned until it can be checked again. Mutation and rollback failures retain terminal handling. Status logs include snapshot waits, restoration waits and the current valid mission type in the shared log folder provided by loader v14. These changes still require consecutive-mission in-game QA.

The build runs focused checks for input edges; exact pack/holder identity; local index one; multiplayer prefix ordering; descent and landing exclusion; native lift predicate; per-pack isolation; next-flight restoration; relocation; later edits; recycled IDs; partial-write rollback; callback return values/failures/cleanup; package identity; bytecode mode; dependencies; privacy and hashes.

The production v0.2 snapshot and settings readers also resolved the running game's local pack and override storage through a VM_READ adapter. Replaying create/cancel/restore against those captured bytes completed six writes to a Lua table and restored the original 280-byte record. This is offline mutation proof, not a native gameplay test.

The research observer never wrote to or injected into the game. Raw recordings, disassembly and read-only tools stay in ignored `artifacts/hover-pack/`. The maintainer confirmed manual cancellation and native landing assistance working before the v1 release. Additional coverage can check: cancel from height, confirm near-ground braking and the next normal-duration flight, then verify recharge, equipment replacement, death/reinforcement, mission exit and host/joined-client behavior. Logs alone do not prove a successful landing.
