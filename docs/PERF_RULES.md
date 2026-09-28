# Performance and safety rules

Holzmann's ten rules for safety-critical code (JPL, 2006), rewritten for a Lua addon that runs inside the game's frame. Each rule names where it is enforced. A rule without a tripwire is a wish; every rule below has one, or says which PR adds it.

Vocabulary: a **hot path** is anything that runs per frame, per sample or per game event while a match is being recorded; a **warm path** runs once per user action (a render, a scrub move, a drawer refresh); a **cold path** runs once per match (finalize, publish) or once per session (load, backfill).

## 1. Simple control flow

No recursion, no `goto`, no coroutines on hot paths. A function on a hot path reads top to bottom.

Enforced by: code review. The only recursion in the codebase is the validation layer's own table walk, which is debug-only and node-capped.

## 2. Every loop has a fixed upper bound

Every buffer that grows during a match has a named cap, and the loop that fills it stops at the cap: positions 900 samples, own track `MAX_ME` 1500, pins `MAX_PINS` 8, objective events `MAX_OBJ_EVENTS` 600, relic events `MAX_RELIC_EVENTS` 400, score samples `MAX_SCORE_SAMPLES` 1000, kills `MAX_KILLS` 1000, group scan 8 tags. Iteration over players is bounded by the scoreboard the game reports.

Enforced by: `Validate.cap` at finalize in dev builds; harness cases on each cap.
Open: the kill feed and the score sampler have a validation cap but no hard stop yet (the game ends matches long before, but the rule wants the stop). Next PR.

## 3. No dynamic allocation after initialisation on hot paths

Pools are created at load with their controls; render passes acquire from pools and release all at once; scratch arrays are hoisted to module scope; no closure is created inside a sampler or a render; strings are not built on hot paths. Cold paths may allocate: finalize packs the timeline once, publish writes the ledger once.

Enforced by: harness tripwires measured with `collectgarbage("count")`: score sample < 1 KB, chart hover < 2 KB, map scrub < 32 KB per tick on a full match (2 KB observed), registry balance delta < 4 KB; `/bgmeter gcprobe` in game; profiler budgets in `observability/prof.lua`.

## 4. Functions fit on a screen

A function does one thing and its cost is visible from its shape. Long functions hide the loop that allocates.

Enforced by: review. `Match.balance`, `Match.surrender` and the map render are the current exceptions and are split as they are touched.

## 5. Assertions, and they cost nothing in release

The validation layer checks invariants in dev builds: monotonic sample clocks, buffer caps, codec round-trip before packing, finite numbers in every stored match, handler errors, balanced profiler spans. In release every check is one call to a shared empty function.

Enforced by: `observability/validate.lua`; harness asserts the release surface is a no-op and the dev surface records each class of failure.

## 6. Data at the smallest scope

Module state is `local`; the single global is `BGMeter`. Per-match state lives in the match table and dies with it; per-render scratch lives in module-level tables reused every pass.

Enforced by: linter `L1` (single global per file); review.

## 7. Every return value of the engine is checked

Every ZOS API call on a recording path goes through `safe()` (pcall + nil on failure). A missing function never reaches the game as an error.

Enforced by: `zenimax/api.lua` late binding; `safe` in capture; harness runs with missing globals.

## 8. No metaprogramming on hot paths

No `setmetatable` tricks, no `loadstring`, no `_G` lookups per sample. Method dispatch on hot paths is a table lookup at most one level deep.

Enforced by: review. The profiler's `wrap_method` is the exception, debug-only.

## 9. Indirection is explicit and bounded

Handlers are registered once, through `zenimax/events.lua`, under `pcall`; there is no dynamic dispatch by string built at runtime.

Enforced by: `events.lua` is the only caller of `EVENT_MANAGER`; harness records every registration.

## 10. Every commit passes the whole gate with zero warnings

The harness (26+ cases), `luac -p` on every file, and the ESOUI lint. A red harness never merges; a pipe never hides it (`set -o pipefail`).

Enforced by: the PR checklist; `qa/gate.sh` where it exists.

## Beyond the ten: what Vulkan SC adds

- **Reserve, never grow.** Pools declare their capacity at creation and the validation layer reports any pool whose active count passes it. Where a pool still grows on demand (ZO_ObjectPool does), the cap is the documented ceiling and the report shows the high-water mark.
- **Fault containment.** A failing handler is logged and counted, and the next event still runs. A failing render leaves the window in its last good state.
- **Determinism.** Given the same stored match, every derived number is the same on every run; nothing depends on `pairs` order where the output is ordered. bgharvest replays real matches through the same decoders the addon uses; the Robot suite of the sibling addons is the model for making that a gate here.
- **Measured budgets.** `docs/PERF_BUDGET.md` holds the numbers; a PR that touches a path updates its row with before and after.
