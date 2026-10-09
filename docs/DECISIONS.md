# Confirmed project decisions

## Power budget — confirmed 2026-10-09

The owner explicitly chose a **5 MW total battery discharge ceiling**, including the internal radar. While the standard radar consumes approximately 300 kW, external discharge availability is approximately **4.7 MW**. This overrides the unresolved alternatives in RELEASE-REVIEW.md.

The implementation must use real battery energy, debit the internal radar without giving it an unlimited or externally refilled energy source, and respect the combined discharge budget. Do not silently implement a 5 MW external port plus an additional 300 kW internal draw. Charging remains limited to 5 MW.

Acceptance must measure total battery debit, useful external delivery and radar consumption together, including saturated external load, external generation present/absent, empty battery, recharge and scanning behavior. Account for finite internal buffers and transfers rather than mistaking buffer initialization for steady-state power. Retain native radar scanning behavior and document the final measured port behavior.

## Nuclear emission scheduling — decision pending

The owner is discussing the full-charge performance/emission scheduling directly with Codex. No batching strategy, delay, projectile reduction or other new explosion behavior has been approved in the project-lead conversation. Do not infer approval from the suggestion in the review. Preserve the original damage-density, propagation and chain requirements until the owner/Codex decision is explicit and recorded. The project lead will review the resulting implementation and test evidence rather than starting a competing redesign.
