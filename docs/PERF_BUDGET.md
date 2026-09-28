# Performance budget

One row per instrumented stage. **Offline** columns come from the harness (`lua bgm_harness.lua ../bgmeter`, the `profiler and validation layers` case, mock clock so time is not meaningful there; allocation is exact). **In game** columns come from `/bgmeter prof` after a real match in a dev build; empty until measured. A PR that touches a stage updates its row with before and after and states where the numbers came from.

Budgets live in `observability/prof.lua` (`BUDGET`); the profiler counts every call that exceeds one. `over` below is that count on the harness run.

Baseline: develop at the validation-layer PR, 2026-09-28. Harness flow: one `mock dm` (16 players) shown and rendered, the Registry opened and refreshed, one recorded 12-sample capture finalised and published.

## Hot paths (per sample, per event)

| stage | calls | KB / call | worst KB | budget | over | in game ms p50 / p95 | note |
|---|---|---|---|---|---|---|---|
| up:BGMeterScoreSample | 12 | 0.24 | 1.0 | 4 ms, 1 KB | 0 | | includes player damage sampling |
| up:BGMeterPosSample | 12 | 0.45 | 2.1 | 4 ms, 2 KB | 1 | | first tick allocates the tracks; steady state under 0.5 KB |
| up:BGMeterMeSample | 12 | 0.08 | 0.4 | 2 ms, 1 KB | 0 | | |
| cap:on_kill | | | | 2 ms, 2 KB | | | not exercised by the harness flow yet |
| cap:on_objective / on_flag / on_murderball | | | | 2 ms, 2 KB | | | idem |
| cap:on_reticle_player | | | | 1 ms, 1 KB | | | |

## Warm paths (per user action)

| stage | calls | KB / call | worst KB | budget | over | in game ms p50 / p95 | note |
|---|---|---|---|---|---|---|---|
| ui:render | 3 | 12.4 | 37.1 | 60 ms, 96 KB | 0 | | sum of the sections below plus layout |
| sec:battle | 3 | 5.9 | 9.6 | | | | scoreboard rows |
| sec:timeline | 3 | 5.8 | 17.5 | | | | score chart |
| sec:header | 3 | 5.0 | 5.5 | | | | |
| sec:haul | 3 | 4.7 | 7.8 | | | | |
| sec:momentum | 3 | 4.7 | 6.3 | | | | calls match:combat_momentum (14 KB per derive, cached?) |
| sec:kills | 2 | 4.2 | 4.8 | | | | |
| sec:balance | 3 | 1.5 | 2.8 | | | | |
| sec:haul_share | 3 | 1.4 | 2.2 | | | | |
| sec:ribbon / race / duels | | 0.6–2.0 | | | | | |
| ui:show_match | 1 | 14.2 | 14.2 | 80 ms | 0 | | |
| map:render | | | | 40 ms, 48 KB | | | needs a match with positions; see the map scrub case (2 KB per tick) |
| map:scrub | | | | 8 ms, 8 KB | | | 0.28 ms / 2 KB per tick on the full synthetic match (#73) |
| menu:refresh | 2 | 53.3 | 61.8 | 30 ms, 64 KB | 0 | | first candidate for a fix |
| panel:refresh | 2 | 47.4 | 53.0 | 10 ms, 16 KB | 2 | | over budget on every call: strings rebuilt for every stat |
| menu:show_menu | 1 | 65.3 | 65.3 | | | | includes the first refresh |
| drawer:* | 2 each | 0 | 0 | | | | drawers closed during the run; measure open |

## Cold paths (per match, per session)

| stage | calls | KB / call | worst KB | budget | over | in game ms | note |
|---|---|---|---|---|---|---|---|
| cap:begin | 1 | 12.2 | 12.2 | | | | allocates the match record and the timeline tables |
| cap:finalize | 1 | 20.0 | 20.0 | 250 ms | 0 | | |
| cap:finalize.pack | 1 | 8.1 | 8.1 | | | | codec packing; pack strings are the output |
| cap:finalize.battle | 1 | 2.8 | 2.8 | | | | scoreboard read |
| cap:finalize.sample | 1 | 0.1 | 0.1 | | | | |
| pub:publish | 1 | 0.0 | | 250 ms | 0 | | children below |
| pub:ledger.record | 1 | 2.5 | 2.5 | | | | |
| pub:faces.record | 1 | 0.3 | 0.3 | | | | |
| pub:records.evaluate | 1 | 0.1 | 0.1 | | | | |
| match:geo | 2 | 10.2 | 19.9 | | | | decode, once per match thanks to `geo_cached` |
| match:combat_momentum | 2 | 14.7 | 28.7 | | | | derived per render today; candidate for caching |
| match:balance | 8 | 0.6 | 0.6 | | | | |
| match:damage_race | 2 | 1.8 | 3.6 | | | | |
| match:flag_lanes | 2 | 1.9 | 3.8 | | | | |

## Reading the table

- Allocation is what the harness can measure exactly; time needs the game. The first in-game `/bgmeter prof` after a real match fills the ms columns, and its copybox output is pasted into the PR that changes any row.
- The two rows over budget today are the Registry panel (47 KB per refresh, budget 16) and the first position sample of a match (allocates the track tables; the budget is per steady-state tick and may be raised for the first call rather than fixed).
- `match:combat_momentum` at 14 KB per derive is the largest derived cost on a render; it is recomputed on every report render and is the second fix candidate after the Registry.
