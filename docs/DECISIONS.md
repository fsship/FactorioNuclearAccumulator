# Confirmed project decisions

## Power budget — confirmed 2026-10-09

The owner explicitly chose a **5 MW total battery discharge ceiling**, including the internal radar. While the standard radar consumes approximately 300 kW, external discharge availability is approximately **4.7 MW**. This overrides the unresolved alternatives in RELEASE-REVIEW.md.

The implementation must use real battery energy, debit the internal radar without giving it an unlimited or externally refilled energy source, and respect the combined discharge budget. Do not silently implement a 5 MW external port plus an additional 300 kW internal draw. Charging remains limited to 5 MW.

Acceptance must measure total battery debit, useful external delivery and radar consumption together, including saturated external load, external generation present/absent, empty battery, recharge and scanning behavior. Account for finite internal buffers and transfers rather than mistaking buffer initialization for steady-state power. Retain native radar scanning behavior and document the final measured port behavior.

## Nuclear emission scheduling — optimization authorized, implementation under review

The owner is working directly with Codex on this part and asked the project lead to wait for that outcome instead of starting a competing redesign.

In the development task, the owner explicitly requested optimization of the reported 1.28-second single-tick full-charge stall, suggesting progressive outward expansion rather than activating all regions at once. The owner explicitly accepts a longer expansion, for example more than ten seconds before the explosion reaches its outer ring.

This authorizes investigating and testing progressive scheduling and its timing tradeoff. It does not authorize reducing the requested projectile population, per-impact damage or density, suppressing friendly fire, or capping chain counts. No exact batching algorithm or final measured performance has been accepted yet. Record the chosen scheduling method, actual propagation timing, total impact counts and peak-tick benchmark before acceptance.

Implementation candidate (0.1.2 / 0.1.3): persistent round-robin emission queue, at most 1,024 scheduled damaging projectiles per tick globally within this mod; native projectile travel and total populations retained. Sequential same-scenario benchmarks measured peak reductions of 90.19% (2.0.77) and 88.66% (2.1.21), with fresh 300-tile targets first damaged around 14 seconds of game time after detonation. Active-save resume and pending legacy carrier migration were tested. See [WAVE-OPTIMIZATION.md](WAVE-OPTIMIZATION.md) for exact metrics, timing tradeoff, count assertions and remaining limits. These are implementation/test results for owner review, not a claim of final acceptance or resolution of the separate radar/tag findings.
