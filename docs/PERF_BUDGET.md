# Performance budget

One row per instrumented stage. **Offline** columns come from the harness (`lua bgm_harness.lua ../bgmeter`, the `profiler and validation layers` case; mock clock, so time is not meaningful there; allocation is exact). **In game** columns come from `/bgmeter prof` in a dev build; the first set was taken on 2026-09-28 over a 50-minute session with two matches recorded, the report, Registry and map used freely (86 stages, 0 unbalanced, validation 0 failures). A PR that touches a stage updates its row with before and after and states where the numbers came from.

Budgets live in `observability/prof.lua` (`BUDGET`); the profiler counts every call that exceeds one.

## Hot paths (per sample, per event)

| stage | calls (game) | ms p50 / p95 / max | KB avg / worst | budget | over | note |
|---|---|---|---|---|---|---|
| up:BGMeterScoreSample | 412 | 0 / 1 / 1 | 0.35 / 18.2 | 4 ms, 1 KB | 29 | was array growth; after presizing (harness) worst tick 0.10 KB |
| up:BGMeterPosSample | 688 | 0 / 1 / 1 | 0.42 / 20.3 | 4 ms, 2 KB | 25 | was array growth of tracks and pins; after presizing (harness) worst tick 0.20 KB |
| up:BGMeterMeSample | 2061 | 0 / 0 / 1 | 0.08 / 48.0 | 2 ms, 1 KB | 15 | was the 1024 to 2048 doubling of three arrays in one tick; after presizing (harness) worst tick 0.00 KB |
| ev:BGMeter_Reticle / cap:on_reticle_player | 5204 | 0 / 0 / 1 | 0.001 / 1.2 | 1 ms, 1 KB | 0 | |
| ev:BGMeter_Obj / cap:on_objective | 340 | 0 / 0 / 1 | 0.10 / 3.1 | 2 ms, 2 KB | 3 | |
| ev:BGMeter_Kill / cap:on_kill | 93 | 0 / 0 / 1 | 0.69 / 1.9 | 2 ms, 2 KB | 0 | |
| up:BGMeterMiniPlay | 1471 | 0 / 1 / 2 | 0.16 / 8.0 | | | the haul minimap loop at 10 Hz while the report is open; second session 440 B per tick; markers now kept between ticks (0.1 acquisitions per tick in the harness, wrapper overhead 15 B) |
| up:BGMeterStandingFx | 1400 | 0 / 0 / 1 | 0 / 0 | | | |

## Warm paths (per user action)

| stage | calls (game) | ms p50 / p95 / max | KB avg / worst | budget | over | note |
|---|---|---|---|---|---|---|
| ui:show_match | 4 | 0 / 256 / **621** | 359 / **1427** | 80 ms | 1 | the first open of a match size in a session; pool creation (fixed: warm-up) |
| ui:render | 43 | 2 / 8 / **491** | 83 / **1218** | 60 ms, 96 KB | 8 | worst cases are the same first opens |
| sec:timeline | 45 | 0 / 8 / 437 | 69 / 1100 | | | score chart: lines per sample per team, lead shading per sample |
| sec:race | 18 | 2 / 128 / 233 | 23 / 387 | | | now the damage lead: one band and one line per sample, a tick per change of hands, a hover per stretch |
| sec:battle | 43 | 1 / 1 / 36 | 7.3 / 41 | | | |
| sec:ribbon | 17 | 0 / 32 / 39 | 7.3 / 41 | | | |
| sec:momentum | 19 | 0 / 32 / 33 | 3.5 / 40 | | | |
| sec:haul | 43 | 0 / 1 / 15 | 4.6 / 61 | | | |
| sec:kills | 18 | 0 / 8 / 12 | 3.5 / 16 | | | |
| sec:header | 43 | 0 / 1 / 1 | 3.3 / 6 | | | |
| menu:refresh | 43 | 2 / 2 / 5 | 26.5 / 53 | 30 ms, 64 KB | 0 | rows memoised on match and lock; harness: 42 KB -> 0.0 KB per refresh with nothing changed |
| panel:refresh | 43 | 1 / 2 / 2 | 25.7 / 46 | 10 ms, 16 KB | **34** | was strings rebuilt per stat; stats memoised on their inputs, veterancy re-read only after a veterancy event |
| menu:show_menu | 10 | 2 / 4 / 5 | 25 / 60 | | | |
| match:geo | **34** | 0 / 2 / 2 | 36 / 339 | | | was 34 decodes in 43 renders; memo of the last three matches (#77) |
| map:scrub | 1349 | 1 / 2 / 5 | 1.4 / 18 | 8 ms, 8 KB | 1 | 0.14 ms / 2 KB per tick on the full synthetic match; sixth and seventh sessions below (#109) |
| map:timechart | 1363 | 0 / 0 / 4 | 0.04 / 0.7 | | | the map's time cards drawn to the slider; seventh session (#109) |
| up:BGMeterCardDrag | 1524 | 0 / 0 / 1 | 0.18 / 0.3 | | | mouse poll at 16 ms while a card is pressed; seventh session (#109) |
| drawer:dev | 261 | 0 / 1 / 48 | 0.15 / 36 | | | dev only |

## Cold paths (per match, per session)

| stage | calls (game) | ms max | KB avg / worst | budget | note |
|---|---|---|---|---|---|
| ev:BGMeter_State | 22 | 5 | 21 / 246 | | begin, finalize and publish run inside it |
| cap:begin | 3 | 1 | 15 / 19 | | |
| cap:finalize | 2 | 5 | 216 / 243 | 250 ms | |
| cap:finalize.pack | 2 | 2 | 113 / 138 | | codec packing |
| cap:finalize.battle | 2 | 0 | 19 / 20 | | |
| pub:publish | 2 | 0 | 6 / 9 | 250 ms | |
| pub:standing.on_data | 9 | 2 | 14 / 38 | | leaderboard pages |
| match:damage_race | 8 | 2 | 49 / 83 | | once per match view (memoised in `derive`) |
| match:combat_momentum | 8 | 0 | 27 / 40 | | idem |
| match:surrender | 8 | 2 | 16 / 23 | | idem |
| match:flag_lanes | 8 | 1 | 9 / 22 | | idem |
| match:balance | 60 | 1 | 0.25 / 1 | | |

## Pools

Controls are created by ZO_ObjectPool on first use and never destroyed. The first open of a match large enough to need more controls than the pools hold pays the creation of every missing control in one frame: about 0.4 ms and 1 KB each. Measured in the harness on an 18-player, 180-sample, 3-team match with a 1000 px chart:

| pool | controls active on that match | reserve target |
|---|---|---|
| battle.rows | 18 | 18 |
| chart.rects (lead shading, ticks, marks) | 289 | 600 |
| chart.lines (score lines) | 537 | 700 |
| chart.skulls | 16 | 40 |
| race.fill | 531 | 650 |
| race.lines | 1253 | 1300 |
| momentum | 16 | 160 |
| kills | 44 | 220 |
| hits | 21 | 220 |
| ribbon.rects / ribbon.pins / occupation | not exercised by that match | 260 / 60 / 12 |
| map.score / map.kills (time cards, up to three series) | 729 / 480 | 740 / 740 |
| map.cohesion / map.solo / map.base / map.control (one series) | 243 each | 250 each |

`ui/warmup.lua` reserves the targets 8 cost units per 50 ms tick after the player activates (a scoreboard row weighs 8, a hit box 2, a rect or line 1; the second session showed one 33 ms tick when eight rows were created together), pausing during matches and combat, about 30 s for a cold session. The `pools` section of `/bgmeter prof` shows created and active per pool; a pool whose created count passes its target in a real session means the target is short and should be raised.

## Third session (21 min, 2026-09-28, after #76-#80)

Confirmed: warm-up max tick 6 ms (was 33); PosSample 0 over budget, worst 0.3 KB (was 136 KB); MeSample 0 KB; ui:show_match 0 ms; panel:refresh 18 KB average over four calls, the first one 65 KB and the rest about 2 KB; validation 0 failures.

New top of the table, the map's first open on a long match:

| stage | calls | ms p50 / p95 / max | KB avg / worst | note |
|---|---|---|---|---|
| map:open | 1 | 256 / 256 / **1534** | 3359 | first open: 4 200 path line controls created (own track 700 points × spline sub 3 × halo and line) |
| map:paths | 742 | 0 / 0 / 1359 | 3.9 / 2919 | the same creation, inside render |
| map:scrub | 735 | 1 / 1 / 2 | 1.4 / 2.1 | per slider move, as designed (#73) |
| map:heat | 4 | 4 / 128 / 146 | 146 / 278 | heat layer recompute on mode change or resize |
| drawer:about | 6 | 0 / 32 / 59 | 359 / 1085 | storage:report walks every stored match (1 MB, 35 ms per open) |
| drawer:faces | 226 | 0 / 1 / 53 | 2.2 / 255 | first open builds the list; scrolling is 2 KB |
| drawer:arenas / marks / saved | 6-9 | max 49-57 | 37-58 per open | lists rebuilt per open |

Fix for the map (this PR): no halo on the path (one control per segment instead of two), the spline subdivision chosen so the path never exceeds 1 500 segments, and the map pools reserved at login (path 1 500, heat 1 024, icons 64, hits 64). Harness: the heavy match's path went from 4 497 to 1 499 segments and a scrub tick from 0.28 to 0.12 ms. The race lost its halo pass too: three line controls per sample instead of five on a two-team match.

Next candidates: storage:report memoised on the History and Ledger revisions; drawer lists memoised on the same revisions.

## Fourth and fifth sessions (2026-09-28, after #81-#85)

Fourth (13.5 min): map:open max 9 ms (was 1 534); no pool created past its target; one map:paths call of 349 ms laying out 1 246 already-created segments (fixed in #84: draw-in over frames); PosSample 370 KB and ScoreSample 82 KB worst ticks when the roster arrived mid-countdown (fixed in #84: roster discovery on the scoreboard event); drawer:about about 246 KB per refresh in game against 2.5 KB in the harness (spans added in #85 to find the phase).

Fifth (7.5 min, the first real 6v6v6): ev:BGMeter_Roster 285 calls at 0 KB; ScoreSample and PosSample 0 over; map:paths max 117 ms for a 120-segment draw-in step, so a segment costs the engine close to a millisecond in anchors alone (step lowered to 40 in this PR; /bgmeter probe anchors measures the calls one by one); up:BGMeterWarmup called 6 608 times while busy (this PR: one check a second while busy); ui:render 1 over. Validation 0 in every session so far.

On ui:render's budget misses: the first render of a match runs derive (damage race, momentum, lanes, surrender, geo) once for that match, 130 to 590 KB, inside sec:timeline. That is cold cost accounted under a warm stage; the budget is meant for the renders after it. A separate stage for the first render per match is the honest fix and stays on the list.

## Sixth and seventh sessions (2026-10-02, the map's time cards, #109)

Sixth (43 min, first cut of the cards, before the fixes): map:scrub 1 246 calls, p50 2 / p95 8 / max 11 ms, 40 over the 8 ms budget; map:timechart 1 249 calls, p50 0 / p95 4 / max **434** ms, 779 KB in total with one call of 706 KB. Two causes, both found by the span: the max was the card pools being created on demand (the map was opened before the warm-up reached them, last in the list), and the p95 was the backward scrub releasing and redrawing every column up to the cursor, up to 732 line anchors per card per tick.

Seventh (147 s, after the fixes, scrub only): map:scrub 1 349 calls, p50 1 / p95 2 / max 5 ms, 1 over; map:timechart 1 363 calls, p50 0 / p95 0 / max 4 ms, 57 KB in total (43 B per call, worst 0.7 KB); up:BGMeterCardDrag 1 524 polls at 0 ms and 177 B. Every card pool stayed at its reserve (map.score 740 created, 729 active with six cards drawn to the end). map:render max 176 ms and map:paths max 158 ms are the first draw-in of the path on open, as in the fourth session, not the cards.

## Reading the table

- Two rows are over budget on every call: the Registry panel (26 KB per refresh, budget 16) and the samplers' array growth spikes (worst 48 KB in one tick of the own-track sampler).
- The first-open hitch (621 ms) is the pool creation; the warm-up moves it out of the first open and spreads it over idle ticks.
- `match:geo` decodes far more often than it should; a per-match memo replaces the one-entry cache.
- The order of the fixes: warm-up (this table's worst case), geo memo (1.2 MB of repeated decode), track preallocation (the in-combat spikes), the Registry panel.
