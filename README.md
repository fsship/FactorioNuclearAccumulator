# Nuclear Accumulator

A Factorio 2.0 mod under development. Target validation baseline: Factorio 2.0.77, base game without Space Age.

## Status

Repository initialized. Mod implementation and game validation are not complete. There is no installable release yet. Do not interpret this specification as verified functionality.

## Required behavior

- Atomic-bomb technology tier; recipe ingredients doubled from the vanilla atomic bomb.
- Native 36 GJ accumulator, maximum 5 MW charge and discharge, initially full for a newly crafted unit.
- Mining and rebuilding must preserve energy without granting repeated free charge.
- Substation-equivalent electrical distribution and standard radar behavior with real energy consumption.
- Remaining-energy fraction `E` determines nuclear radius multiplier `M = 1 + 9 * E`.
- Both damaging waves expand over time at vanilla propagation speeds. Each wave uses `round(N0 * M * M)` impacts while preserving individual impact damage, type, local radius and appropriate attenuation.
- Friendly-fire damage and uncapped chain reactions; exactly one explosion per destroyed station.
- Confirmed manual detonation and red/green circuit input `D > 0`.
- Circuit outputs: `E` stored MJ (integer, 0–36000), `H` health, `P` charge percentage.
- Player and robot construction/mining, blueprints, wire topology, save/load and helper cleanup.
- English and Simplified Chinese localization.

## Delivery and verification

Deliver a properly structured installable ZIP, complete source, installation/user documentation, reproducible tests and an honest test report. Static validation, headless engine testing and graphical-client testing must be distinguished. Tests not executed must remain marked unverified.

Full-charge explosions involve approximately 200,000 damaging projectiles in vanilla 2.0.77 scaling. Performance, lifecycle correctness and energy conservation are explicit acceptance gates. Any approximation or major gameplay deviation must be documented before it is accepted.

## Reference baseline

- https://github.com/wube/factorio-data/tree/2.0.77
- https://lua-api.factorio.com/2.0.77/runtime-api.json
- https://lua-api.factorio.com/2.0.77/prototype-api.json

Game binaries and proprietary base-game assets will not be bundled with this mod.
