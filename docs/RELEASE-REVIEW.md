# Nuclear Accumulator release review

Reviewed commit: 7a9d5e4d47fbeab46f24efb44ee83e4fc725c212 (work), read-only, 2026-10-09.
Specification: [USER_SPEC.md](https://github.com/fsship/FactorioNuclearAccumulator/blob/main/docs/USER_SPEC.md).
This review inspected repository implementation and recorded engine logs; it did not rerun Factorio.

## Release identity and verified evidence

- The Factorio 2.0.77 artifact is releases/nuclear-accumulator_0.1.0.zip. 0.1.1 targets 2.1.21 experimental.
- Independently decoded the 0.1.0 ZIP through the GitHub connector: SHA-256 e11b76b43fc10c52582795cf54f1cb5605987c450abcd8cbf785d6561150685c, matching releases/SHA256SUMS.txt. All 35 ZIP entries exactly match Git blob hashes for all 35 files in nuclear-accumulator_0.1.0/.
- 0.1.0 is the two-item/two-main-entity, discard-charge-on-mining design. This is disclosed and satisfies the original anti-refill requirement; it does not implement charge-carrying recovery.
- charge-state-tests/ammo/nuclear-accumulator_0.2.0/ is a failed experiment, not a release. Its real 2.0.77 log records storage ammo values {12335, 36001} after three mined items. The assertion fails because the zero-charge sentinel item disappears. This corroborates the count-loss and +1 MJ encoding result.
- charge-state-tests/tags/nuclear-accumulator_0.3.0/ is a promising isolated experiment. Actual 2.0.77 logs show nine native robot builds, three extra recycle cycles, surviving fractional-joule tags and zero tags, actual crafting output, and NA AMMO COMPLETE. It is not integrated into the shipping ZIP.
- Real-engine evidence exists for 2.0.77 native charging/discharging, isolated radar scanning and consumption, robot lifecycle, and native damage at distance. GUI testing is API doubles only. A save created during initialization was subsequently loaded in another process; this is a real but narrow persistence check.

## Prioritized findings and fixes

### 1. P1: Radar source attribution does not meet the literal own-battery requirement

Type: actual implementation/spec mismatch, not a fake test.

[entities.lua L25-L30](https://github.com/fsship/FactorioNuclearAccumulator/blob/7a9d5e4d47fbeab46f24efb44ee83e4fc725c212/nuclear-accumulator_0.1.0/prototypes/entities.lua#L25-L30) copies an ordinary grid-powered radar with no input restriction or battery-transfer logic. [README L26](https://github.com/fsship/FactorioNuclearAccumulator/blob/7a9d5e4d47fbeab46f24efb44ee83e4fc725c212/nuclear-accumulator_0.1.0/README.md#L26) explicitly says external generation may supply radar without debiting this battery. [acceptance control L30-L41](https://github.com/fsship/FactorioNuclearAccumulator/blob/7a9d5e4d47fbeab46f24efb44ee83e4fc725c212/nuclear-accumulator_0.1.0/tests/acceptance/zz-na-tests_0.1.0/control.lua#L30-L41) tests only isolated consumption and then external charging, not exclusive battery debit.

Required next step: resolve the power semantic before changing gameplay. Strict own-battery radar can use a radar energy source with network input_flow_limit=0 and bounded transfers from actual accumulator.energy to radar.energy. Debit exactly what is credited, keep native radar scanning and real energy, and account for buffer energy during teardown/moves.

Important tradeoff: retaining a native 5 MW external accumulator output port plus a separately debited approximately 300 kW radar allows approximately 5.3 MW total cell discharge. Retaining a hard 5 MW total cell ceiling while radar runs requires reserving internal draw (approximately 4.7 MW external availability), or a more involved scheduler whose correctness needs engine measurement. Do not silently claim both “5 MW external output” and “5 MW total including radar” after direct internal transfers.

Acceptance: external generator present/absent, empty battery, sustained scan-rate comparison with vanilla, zero external radar refill, battery+radar-buffer energy accounting, and saturated external-load measurement under the selected semantic.

### 2. P1 before promoting tags: integrate and migrate safely, then rerun the whole release

Type: experimental branch release-readiness gap; not a defect in the documented lossy 0.1.0 behavior.

[experiment boundary L39-L44](https://github.com/fsship/FactorioNuclearAccumulator/blob/7a9d5e4d47fbeab46f24efb44ee83e4fc725c212/charge-state-tests/TEST-RESULTS.md#L39-L44) correctly admits no old-save migration, no real player placement test, and no complete nuclear regression. The tag experiment removes the used prototype. Promoting it directly risks deleting old used entities/items and invalidating old blueprints.

Integrate with an explicit compatibility/migration design for old fresh and used items, placed stations, existing energy, wire topology, ghosts and blueprints. Never reinterpret an old used item as an untagged new full-energy entitlement. Preserve fresh items' entitlement once; preserve real energy of existing stations. Missing/invalid recovered state must not mint full charge. Test new-save and old-save upgrades independently, including full/partial/empty inventories, robot cargo and ground stacks.

[tags control L73-L105](https://github.com/fsship/FactorioNuclearAccumulator/blob/7a9d5e4d47fbeab46f24efb44ee83e4fc725c212/charge-state-tests/tags/nuclear-accumulator_0.3.0/control.lua#L73-L105) includes a same-tick cursor fallback and defaults script-raised built/revive to full energy. The latter is not a vanilla robot-path failure, but means script interoperability does not conserve energy automatically. Define/test that boundary rather than claiming universal anti-refill.

[tags mining L125-L140](https://github.com/fsship/FactorioNuclearAccumulator/blob/7a9d5e4d47fbeab46f24efb44ee83e4fc725c212/charge-state-tests/tags/nuclear-accumulator_0.3.0/control.lua#L125-L140) saves only battery.energy, then destroys radar buffer. If strict radar transfer is added, explicitly decide how buffer energy is conserved or reported as loss.

### 3. P1 acceptance defect: current chain assertion cannot establish a secondary explosion

Type: false-positive-prone test, not proof that production chain explosions are broken.

[acceptance L73-L80](https://github.com/fsship/FactorioNuclearAccumulator/blob/7a9d5e4d47fbeab46f24efb44ee83e4fc725c212/nuclear-accumulator_0.1.0/tests/acceptance/zz-na-tests_0.1.0/control.lua#L73-L80) creates an empty second station, then only asserts it is invalid. The same test would pass if the second station simply died without exploding.

Production [control L62-L70, L103-L105](https://github.com/fsship/FactorioNuclearAccumulator/blob/7a9d5e4d47fbeab46f24efb44ee83e4fc725c212/nuclear-accumulator_0.1.0/control.lua#L62-L70) does route death through a guarded blast function, takes current energy before cleanup, and removes its registry before spawning the projectile. No clear idempotence bug found statically.

Add engine-observable launch records or test-only instrumentation that records station identity, instantaneous pre-death energy, selected tier and launch count. Assert exactly one secondary blast per station for multiple charge levels and simultaneous circuit/death attempts. Use a witness target outside the first blast footprint but within a secondary footprint where practical. Save/reload while native blast projectiles are active and confirm secondary behavior and no duplicate launches.

### 4. P2 acceptance defect: higher-tier timing reuses prior damage

Type: contaminated measurement, not evidence of wrong native propagation.

[acceptance L68-L76](https://github.com/fsship/FactorioNuclearAccumulator/blob/7a9d5e4d47fbeab46f24efb44ee83e4fc725c212/nuclear-accumulator_0.1.0/tests/acceptance/zz-na-tests_0.1.0/control.lua#L68-L76) resets timestamps for 50%/100% but never repairs/recreates target walls. [L90-L93](https://github.com/fsship/FactorioNuclearAccumulator/blob/7a9d5e4d47fbeab46f24efb44ee83e4fc725c212/nuclear-accumulator_0.1.0/tests/acceptance/zz-na-tests_0.1.0/control.lua#L90-L93) treats existing damage or dead references as new damage. Logs consequently mark near-wall damage at tick 600 and tick 1400, precisely the later blast launch ticks.

The 0% 10/25-tile timing remains valid. Newly reached 150/300-tile targets also remain useful evidence. Do not discard those valid results or call all engine tests false.

Run each charge in a fresh isolated arena with undamaged targets and log on_entity_damaged event ticks relative to its own launch. Add normalized-radius target rings, multiple fixed random seeds and high-health targets to measure damage density without early target destruction masking variation. Existing static N~M² assertions are meaningful structural evidence, not empirical density measurements.

### 5. P2: Circuit red/green cancellation needs an explicit contract/test

Type: behavioral ambiguity against “D>0 supports red and green”, not an unequivocal API error.

[control L181](https://github.com/fsship/FactorioNuclearAccumulator/blob/7a9d5e4d47fbeab46f24efb44ee83e4fc725c212/nuclear-accumulator_0.1.0/control.lua#L181) reads a combined red+green D. Therefore red D=1 and green D=-1 does not detonate. README discloses sum semantics, but separate-color tests do not address cancellation.

If the intended contract is “either wire has D>0”, read each separately and OR the positive checks. If sum semantics are intended, keep it and add a cancellation test. Also test simultaneous colors, no D output from helpers, independent networks, and restored blueprint wire topology.

### 6. P2/P3: Correct API facts and assert parsed attenuation behavior

[explosions.lua L16-L29](https://github.com/fsship/FactorioNuclearAccumulator/blob/7a9d5e4d47fbeab46f24efb44ee83e4fc725c212/nuclear-accumulator_0.1.0/prototypes/explosions.lua#L16-L29) and [README L61](https://github.com/fsship/FactorioNuclearAccumulator/blob/7a9d5e4d47fbeab46f24efb44ee83e4fc725c212/nuclear-accumulator_0.1.0/README.md#L61) incorrectly state this area action's repeat_count is uint16. In the pinned 2.0.77 prototype schema, TriggerItem.repeat_count is uint32; TriggerEffectItem.repeat_count is uint16. The existing split preserves counts and is not itself a damage bug. Correct the explanation; simplification is optional.

[explosions L48-L51](https://github.com/fsship/FactorioNuclearAccumulator/blob/7a9d5e4d47fbeab46f24efb44ee83e4fc725c212/nuclear-accumulator_0.1.0/prototypes/explosions.lua#L48-L51) assigns fractional scaled distance thresholds. The 2.0.77 DamageEntityTriggerEffectItem threshold fields are uint16. Its static test examines Lua data.raw before engine conversion, so it cannot prove exact fractional thresholds in the engine. Explicitly choose integer rounding, disclose the small approximation, and validate compiled/runtime behavior where accessible. No evidence found of a catastrophic attenuation error.

[experiment report L35](https://github.com/fsship/FactorioNuclearAccumulator/blob/7a9d5e4d47fbeab46f24efb44ee83e4fc725c212/charge-state-tests/TEST-RESULTS.md#L35) and [tags control L90](https://github.com/fsship/FactorioNuclearAccumulator/blob/7a9d5e4d47fbeab46f24efb44ee83e4fc725c212/charge-state-tests/tags/nuclear-accumulator_0.3.0/control.lua#L90) wrongly imply consumed_items is 2.1-only. Official 2.0.77 on_built_entity already exposes consumed_items. Code tries it first, so the comment is not a demonstrated production failure. Test this real player path and rely on the supported inventory rather than an unnecessary cursor-state assumption.

Pinned API sources:
- https://lua-api.factorio.com/2.0.77/runtime-api.json
- https://lua-api.factorio.com/2.0.77/prototype-api.json

## Additional acceptance required before a final “fully validated” claim

- Native player place/mine, real GUI arm/cancel/expiry/confirm, multiplayer interactions; API doubles are not graphical-client evidence.
- Save a running partially discharged station and an active blast/chain, stop the process, reload, verify actual charge, helpers, output and exactly-once behavior. Current lifecycle assertion only checks a near-full initialized station.
- Blueprint build with actual red/green/copper connections, recovered items, and unrelated stations.
- Surface deletion, cross-surface movement, force merge and helper removal/repair with no orphan references/entities or energy duplication.
- Isolated drill test should assert actual mined output, not just a positive machine energy buffer.
- Full integration regression using the exact final ZIP. Keep separate 2.0 and optional 2.1 manifests.
- Report peak tick time and finite multi-station stress at fixed hardware/seed; do not promise unlimited chain performance. Current 2.0.77 log reports maximum tick 1276.924 ms. The cost is disclosed; preserving 200,000 projectiles means this is a performance tradeoff, not a reason to silently cap damage or chain count.

## Evidence paths

- releases/nuclear-accumulator_0.1.0.zip
- releases/SHA256SUMS.txt
- docs/install-zip-20.log
- nuclear-accumulator_0.1.0/tests/logs/2.0.77/acceptance-runtime.log
- nuclear-accumulator_0.1.0/tests/logs/2.0.77/final-sprite-lifecycle-runtime.log
- nuclear-accumulator_0.1.0/tests/logs/gui-unit.log
- charge-state-tests/ammo/logs/ammo-confirm20/runtime.log
- charge-state-tests/tags/logs/tag-confirm20/runtime.log

Overall: substantial real implementation and genuine engine evidence, with honest documented limitations. No static evidence that native damage count, local impact radius, basic damage or speed were secretly replaced or reduced. The main implementation/spec decision is radar source attribution; the main immediate engineering step is a migration-safe tag integration and stronger end-to-end acceptance, not simply repackaging the experimental directory.

