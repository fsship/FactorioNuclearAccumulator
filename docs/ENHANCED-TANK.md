# 强化裂变坦克

新增至当前 Mod，当前版本 0.3.1，仍维护一份 `mod/` 源码。支持原版 2.0.77 和 2.1.21 experimental，不依赖 Space Age。

## 参数

| 项目 | 实现 |
| --- | --- |
| 玩家装备网格 | 15×17，全部 255 格可用，内置系统不占格子 |
| 基础生命值 | 10,000，即原版 2,000 的五倍，保留原抗性 |
| 行驶 | 电力供能，同地形普通煤炭坦克的 75% 稳态速度 |
| 操作 | 原生驾驶和远程驾驶，主车 `allow_remote_driving=true` |
| 内置电站 | 1 个强化原生裂变装备模块，持续 10 MW，无需化学燃料 |
| 内置储能 | 100 MJ 原生装备电池，从空电启动 |
| 主炮 | 基础 30×4=120 格，原炮弹伤害与科技类别 |
| 自动激光 | 6 个独立原生自动防御装备，基础 24×3=72 格 |
| 激光伤害 | 基础 20×10=200 laser，另受目标抗性和原生科技规则影响 |
| 激光射击 | 沿用 40 tick 冷却、800 kJ/次，停放或无人驾驶时也自动选敌 |
| 雷达 | 原生揭示与扫描，额定 300 kW，从内置电池扣电 |
| 外加装备供电 | 内置电池向玩家装备网格提供最高 1.5 MW 接口 |
| 自动修复 | 脱战 10 秒后恢复 50 HP/秒，受击或开火重新计时 |

研究“强化裂变坦克”解锁车辆和四种远程炮弹改装配方。前置为原版坦克、裂变反应堆装备、激光炮塔和电池组 MK2；科学包/研究时间沿用裂变装备科技。制造 60 秒，材料为：坦克×1、裂变反应堆装备×1、激光炮塔×6、雷达×1、电池组 MK2×1、电动机×40、处理器×100、轻质结构×50。

复用原版坦克外观，加入组合图标和中英文说明。原生车辆背包、装备和地图远程驾驶操作保持可用；真人远程操作与外观还需图形客户端验收。

## 炮弹与版本差异

2.0 炮弹动作另有 30 格 `max_range`，仅扩大武器射程仍会在约 30 格终止。因此新增普通、爆破、铀芯、爆破铀芯四种远程改装弹：每个原弹 1:1 改装，投射上限乘四，保留弹道实体、伤害、散布、最小射距和科技类别。**2.0 请装填远程改装弹。**

2.1 改为 `target_type=position`、`clamp_position=true`，已取消独立 30 格动作上限。本 Mod 保留原生规则，2.1 普通弹也可使用增强武器的目标射程；四种改装配方继续提供统一接口。原版枪、炮弹和坦克定义未修改。原有弹药射程修正和随机散布仍生效，120 格是基础参数，不是每发炮弹的硬圆边界。

## 真实电力与辅助实体

两版引擎均已实测拒绝 `car.energy_source.type=electric`，只接受 burner/void。本版先扣除真实内置装备电池 J，再等量增加 `LuaBurner.remaining_burning_fuel`，由原生引擎消费已付费缓冲驱动。主车无燃料槽，仅接受不可制造的私有电驱类型；不使用 void 无限驱动或模拟电量。缓冲最多约两 tick（20 kJ），燃烧效率为 1。

内置系统放在隐藏、无碰撞、不可操作/回收、关闭远程驾驶的辅助车网格中：1 个 10 MW 裂变模块、1 个 100 MJ 电池和 6 个自动激光。它只承载装备，不行驶、不占玩家格子；另外有一个隐藏雷达。玩家正常操作的是唯一可见主车。目标选择、射击、生成电力和伤害均由原生引擎完成，Lua 不扫描周围敌人。

雷达网络输入限制为 0 W，只接受已扣除的内置电量；没有附近电网独立给它供电的路径。外加装备的接口也先扣电再充值，原生装备自行消费及发电。默认无射速升级时，驾驶约 0.6 MW、雷达 0.3 MW、六门激光约 7.2 MW，合计 8.1 MW。科技提高射速或额外高功耗装备会改变负载，电池可能放电，不能保证任意升级组合永不缺电。

速度经两版物理实测校准：最高速度燃料因子保持 1，以 0.75² 推力因子达到 75% 稳态速度。两版对小于一的最高速度因子处理不同，直接设 0.75 不能保证目标。对照以同地形、普通煤炭、无速度改写 Mod 的原版坦克为准，未替换加速/转向物理。

## 脱战自动修复

0.3.1 为强化坦克加入内置被动修复，无需修理包，不占装备格，也不从电池额外扣电。最后一次受到攻击、内置激光开火或驾驶者/乘客发出射击指令后，等待 **600 tick（10 秒）**；随后每 **6 tick（0.1 秒）** 恢复 **5 HP**，约 **50 HP/秒**。以基础 10,000 HP 计算，从极低血量回满约需 200 秒，加上初始 10 秒冷却。普通行驶不打断修复。

新的伤害或射击立即重置冷却。原生抗性完全阻挡的正伤害攻击也算战斗；持续射击指令（包含装填或向空地射击）继续计时。激光使用仅属于该辅助系统的原生 `script` 源效果报告开火；受击事件由引擎过滤为主坦克，不处理全图伤害事件，不增加核爆每个小爆炸的 Lua 调用。没有为修复寻找或逐实体扫描附近敌人。

修复读取真实 `LuaEntity.health` 和当前品质的 `prototype.get_max_health(quality)`，限制在最大生命值内，死亡车辆不复活。计时随各坦克分别保存在 `storage`；正常保存读取不会重置冷却，也不会按游戏外经过的时间补发回血。新建和克隆从新的 10 秒等待开始。未收到事件的第三方脚本直接写 `health` 不算一次攻击；玩家外加的独立攻击装备未额外追踪，内置六门激光与原生驾驶射击指令纳入计时。

## 生命周期与限制

保存保留车辆、已付费缓冲、真实内置能量及装备引用。新建、克隆和修复缺失电池从零开始。正常回收使用原生 `item-with-entity-data`，保留玩家网格及其中电量；内置电池/雷达缓存丢弃，再放置后由裂变模块充入，不能重放满电。

死亡、回收、普通移除和注册销毁清理辅助实体；意外辅助实体克隆会立即丢弃。跨地表保留内置电池，雷达重建并转移缓存，跨地表未完成扫描进度丢弃。死亡使用原版坦克效果。只读检查接口：`remote.call("na-enhanced-tank", "inspect", entity.unit_number)`；转移计数用于核验，储能始终以原生对象为准。

尚未穷尽图形客户端真人远程驾驶、多人、品质/DLC 或其他 Mod 组合。激光的十倍指基础伤害，科技按自动防御装备/激光弹药原生规则生效，建筑炮塔特有加成不宣称完全相同。原核能蓄电站共享电网雷达的既有限制不在本次改动范围。

## 测试入口

`--suite tank` 验证真实驾驶对照、无电不能加速、6 门自动激光与敌友/边界、100 格实弹命中、原生雷达扫描与扣电、真实制造/回收、辅助克隆/清理、跨地表及行驶中部分充电保存/读取；0.3.1 另验证脱战修复、受击/开火暂停、抗性完全挡伤、回血上限和修复中存档。当前证据在 `test-results/releases/0.3.1/`；初版坦克及预期失败的 electric-car API 探针保留在 `test-results/releases/0.3.0/`。

2026-10-13 两版最终 ZIP 均完成全部五个引擎套件及 tags/queue/tank 三种真实服务器保存读取。坦克实测如下：

| 验证 | 2.0.77 | 2.1.21 experimental |
| --- | --- | --- |
| 原版/电驱速度（tile/tick，tick 1200） | 0.235288 / 0.176409 | 0.235288 / 0.176409 |
| 电驱/原版速度比 | 0.749759（趋于 0.75） | 0.749759（趋于 0.75） |
| 六门停放无人激光对 60 格目标的命中数（tick 1200） | 175 | 175 |
| 单次原生激光基础伤害 | 200 laser | 200 laser |
| 85 格敌人和友军不受自动激光伤害 | 通过 | 通过 |
| 100 格墙阵实际被主炮弹道击中 | 通过 | 通过 |
| 移动雷达真实扇区扫描、移除发电后电池扣电 | 通过，300,000 J/s | 通过，300,000 J/s |
| 无发电/储能不能加速、转移计数与实际扣电相等 | 通过 | 通过 |
| 真实组装机制造、原生采矿物品保留 15×17 与装备精确电量 | 通过 | 通过 |
| 约 42.123 MJ 内置电池、行驶状态及装备引用跨进程保存读取 | 通过 | 通过 |
| 主车/辅助克隆、正常移除、死亡及跨地表清理 | 通过 | 通过 |
| 原核能蓄电站四套件完整回归 | 通过 | 通过 |

原始日志、安装包哈希和机器可读结果见 [test-results/releases/0.3.0/](../test-results/releases/0.3.0/)。并行功能回归的耗时不作为新的性能对照。真人图形客户端远程驾驶和视觉没有混作上述 PASS。

2026-10-14，0.3.1 两个最终 ZIP 在两版引擎均通过全部五个套件。新增修复实测：2 秒恢复约 99.998 HP（原生生命值浮点舍入），连续受击、自动激光开火、驾驶射击或完全被抗性挡住的攻击会暂停/重置计时；最大生命值停止，致死不复活。冷却期间 tick 1200 和回血期间 tick 2100 分别真实保存、停止进程、重新读取，两次都通过。完整日志、范围及未测项目见 [0.3.1 测试记录](../test-results/releases/0.3.1/README.md)。

```sh
python3 scripts/package.py
python3 tests/run.py --factorio /path/to/factorio --suite tank --work work/new-tank-run
python3 tests/run.py --factorio /path/to/factorio --mod-zip releases/factorio-2.0/nuclear-accumulator_0.3.1.zip --work work/new-release-run
```

## English quick guide

Research Enhanced Fission Tank after Tank, Fission Reactor Equipment, Laser Turret and Battery MK2. Craft from one tank/reactor/battery, six laser turrets, one radar, 40 electric engines, 100 processing units and 50 low density structures. The full 15×17 grid remains available, health is 10,000, native remote driving is enabled, and steady speed is 75% of a vanilla coal tank on identical terrain.

The private native equipment system produces 10 MW, stores 100 MJ, powers six automatic 72-tile lasers (200 base damage) and a 300 kW radar. Actual battery joules fund a native drive buffer because cars cannot directly use an electric energy source; chemical fuel and infinite vehicle drive are not supplied. The accessory bus is limited to 1.5 MW. In 2.0 use 1:1 long-range shell conversions to bypass vanilla shells' 30-tile projectile cap; 2.1 follows native target range. The main cannon's base range is 120. Mining preserves user equipment and discards private storage, which recharges after placement. Real graphical remote-driving, multiplayer and broad compatibility checks remain pending.

Version 0.3.1 adds passive self-repair: wait 10 game seconds after the last incoming hit, built-in laser shot or driver/passenger shooting input, then regenerate 50 HP/s, capped at the actual maximum health. New combat restarts the delay. It needs no repair packs or equipment slots and draws no additional power. Each vehicle's combat timer and health survive saving and reloading, with no offline healing. Independent player-added attack equipment and direct health edits by other scripts are outside the combat detector.
