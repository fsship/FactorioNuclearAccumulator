# Nuclear Accumulator / 核能蓄电站

完整 Factorio Mod，原版游戏即可运行，无需 Space Age。包含源码、中文/英文游戏文本、原生电网实现、原生核爆原型和可复现无界面测试。

## 安装与版本

- Factorio **2.0.77 稳定版**：使用 `nuclear-accumulator_0.1.0.zip`。
- Factorio **2.1.21**：使用 `nuclear-accumulator_0.1.1.zip`。本次从官方 experimental 下载通道取得 2.1.21，它不是本次验证的稳定发行版。不能声称已经验证尚未取得的 2.1 稳定版。
- ZIP 整体放入游戏的 `mods` 文件夹，不必解压。也可把含 `info.json` 的源码文件夹放入 `mods`。只安装与你的游戏主次版本匹配的一个包。
- 两个包功能源码相同，只有 `info.json` 的版本及基础游戏依赖不同。2.1 明确拒绝加载标记为 2.0 的包，因此提供分开打包的版本。
- 常见 mods 路径：Windows `%APPDATA%/Factorio/mods`；Linux `~/.factorio/mods`；macOS `~/Library/Application Support/factorio/mods`。
- `settings.lua` 不需要：容量、功率和引爆规则固定，没有必需的可配置开关。

## 研究、制造与使用

研究原版 **原子弹**科技直接解锁配方，不增加额外科技层级，也不修改原版原子弹的配方、弹药或行为。制造材料在数据阶段读取原版原子弹配方并逐项加倍。在已验证版本中为 **20 处理器、20 炸药、60 铀-235**。制造时间沿用原子弹的 50 秒。

建筑复用配电站外观，具有配电站与核弹组合图标、自动地图标记、2×2 格选择区域、原版配电站碰撞体积和 1,000 基础生命值。可以连接铜线、红线、绿线。供电范围及铜线连接距离继承当前原版 Substation；本次版本为供电半径 9 格、最大连接距离 18 格。

将鼠标放在建筑上，按 **Ctrl+Shift+N** 打开原生 GUI。快捷键可在游戏控制设置中更改。GUI 显示真实电量、生命值、理论倍率与两道波的理论半径；点击“准备手动引爆”，再在 10 秒内点击“确认核爆”。关闭窗口或确认超时会取消使能。选中建筑属于其他阵营时无法手动打开控制窗口。正常 E 键打开电网窗口若产生对应实体的 GUI 事件，也会打开检查窗口；快捷键是稳定入口。

## 真实电网与回收防刷电

电池是隐藏的**原生 accumulator**，容量 **36 GJ = 36,000 MJ**，原生电源的输入、输出限制均为 **5 MW**，优先级为普通蓄电器的 `tertiary`。储能直接读写 `LuaEntity.energy`，不存在独立的模拟电量。新制造物品首次放置时向这块真实电池注入 36 GJ；之后所有充放电由游戏电网调度。

雷达是原生 radar，保留当前原版的持续揭示、远程扫描、扫描速度、300 kW 消耗及扫描能量参数，和电池都位于主配电站的供电范围内。孤立电网中电池通过真实电网为雷达与周围机器供电，电池实际储能随之下降。连接外部发电设施时，雷达和其他消费者可像原版一样从外部电网取电，剩余电量充入电池；不会额外从电池重复扣款。雷达具有原版消费者缓存，断电后可能使用缓存短暂运行，这不是无限能源。电池的 5 MW 输出上限包含通过它向雷达与其他消费者供出的电力。

**回收采用有损、无标签的可靠方案：**

1. 制造得到 `nuclear-accumulator`（出厂满电）物品，放置同名主实体。
2. 玩家或机器人正常回收任一版本，固定返回 `nuclear-accumulator-used`（已使用，空电）物品。原储能丢失，回收不爆炸。
3. 回收物品放置 `nuclear-accumulator-used` 主实体，从 **0 J** 开始，必须由外部发电设施充电。
4. 两种主实体的名称、外观、电力、雷达、信号、生命值和核爆规则相同，差别只在首次放置的电量。克隆不复制储能；脚本发现已存在但尚未登记的实体也从空电开始。

使用两种主原型是因为实际引擎的机器人虚影只请求一种放置物品，不能自动在不同物品之间替换。**出厂版蓝图请求出厂版物品，回收版蓝图请求回收版物品。**两者均支持原生蓝图和机器人。蓝图不会复制充电状态，也不会复制隐藏辅助实体。不能把仅有回收物品的箱子用于填充出厂版虚影；需要从回收版实体制作蓝图，或手动放置回收物品。这一限制已实际测试确认，没有以未验证的物品标签 API 规避它。

## 电路信号

红、绿线连接可见主建筑。一个隐藏 constant-combinator 通过 `LuaWireConnector.connect_to` 与主实体对应线路连接。

| 信号 | 定义 |
| --- | --- |
| E | 实际电池储能 / 1,000,000，向下取整，单位 MJ，范围 0–36,000 |
| H | 主实体实际生命值，向下取整 |
| P | 实际储能百分比，向下取整，范围 0–100 |
| D | 输入。红、绿线的 D 之和大于零即引爆 |

输出只有 E/H/P，绝不输出 D，因此不会自触发。输出和 D 检查按实体编号分成 30 个桶，均匀分布在每 tick；每座最多延迟 **29 tick（约 0.5 秒）**。GUI 每 30 tick 刷新。原生线路由蓝图和复制粘贴保存；输出规则固定，无需复制隐藏组合器的设置。若多座建筑连接同一电路，其输出会按原版网络规则相加；独立线路互不影响。没有额外的电路引爆禁用开关。

## 核爆

死亡、确认手动引爆和 D 指令均触发一次核爆。普通回收、拆除规划、取消虚影、脚本直接移除和删除地表只清理辅助实体，不爆炸。受到真实伤害导致死亡时，在死亡事件中立即读取仍然存活的隐藏电池的实际能量，不使用周期缓存，随后移除记录和辅助实体，再生成核爆弹道。一次性标记在任何销毁或弹道伤害之前设置，防止事件重入。

设 `E = 当前能量 / 36,000,000,000 J`，理论倍率 `M = 1 + 9E`。在本 Mod 的 data-final-fixes 阶段检查**当时已加载的原型** `atomic-rocket.action`，只识别原版两个真实伤害分支：

- `atomic-bomb-ground-zero-projectile`：本次基准覆盖半径 7 格、1,000 个弹道、局部作用半径 3 格、100 explosion 基础伤害。
- `atomic-bomb-wave`：本次基准覆盖半径 35 格、1,000 个弹道、局部作用半径 3 格、400 explosion 基础伤害。

实际引爆使用最近的 **1% 电量档**：`q = clamp(round(100E), 0, 100)`、`Mq = 1 + 9q/100`。这是明确的 101 档近似：倍率最大舍入误差 0.045；35 格基准的外圈最大半径误差约 1.575 格。0%、25%、50%、75%、100% 的指定倍率均能精确表示。GUI 显示未量化的理论半径，并明确提示实际分档。

每道伤害波使用 `半径 = R0 × Mq`、`数量 = round(N0 × Mq²)`。50% 两道各 **30,250** 个弹道；100% 两道各 **100,000** 个弹道。原生 `repeat_count` 是 uint16，满电的每道波拆成 65,535 + 34,465 两个同分布 area 触发，既不截断，也不提高单次伤害。

弹道继续使用原版 starting_speed、starting_speed_deviation、acceleration、speed_modifier、局部 3 格作用半径和伤害类型；伤害上下限倍率保持原版值，距离衰减阈值按 Mq 拉伸，保留相对于扩大核爆半径的原版衰减形状。近处先受伤、远处后受伤。仅复制这两种伤害弹道以调整衰减阈值，不修改原版原型。

原版的 cluster-nuke-explosion、fire-smoke、nuke-shockwave、nuclear-smoke 是另外的视觉分支：扩展其分布半径，**保留原来的数量**，避免把不负责主体伤害的 repeat_count 全部乘 100。地表变更、装饰、中心闪光及其他局部效果保留原版规则，视觉烟雾在扩大区域内会更稀疏；并未把环境效果密度也扩大到百倍。

伤害目标规则继承原版，友军设施会被击毁，同类建筑死亡时按**它自己的即时能量**再次爆炸；没有连锁数量上限。Lua 不逐 tick 遍历爆炸半径内所有实体，也没有一次超大 area damage 替代冲击波。

## 架构与生命周期

单个 Factorio 原型具有固定实体类型；AccumulatorPrototype、ElectricPolePrototype、RadarPrototype 的职责不能在同一个实体类型上组合。因此每座建筑由一个可见 electric-pole 和三个隐藏实体组成：

- `na-battery`：原生 36 GJ accumulator。
- `na-radar`：原生 radar。
- `na-output`：原生 constant-combinator，使用 2.x logistic sections 输出信号。

辅助实体无碰撞、无地图绘制、不参与蓝图/拆除、不可选择、不可单独采矿，并在运行时设为不可受伤。它们不是额外的玩家可操作建筑。电池和雷达都在原配电站的范围内，自动加入真实电网。自动地图标签在地块已揭示后显示组合物品图标，最多延迟约 5 秒，并在移除时清理。

使用 `on_built_entity`、`on_robot_built_entity`、`script_raised_built/revive`、`on_entity_cloned`、玩家/机器人采矿、实体死亡和 `on_object_destroyed` 等原生事件。`storage` 保存 LuaEntity 引用、索引、轮询桶及注册号，保存后重载继续使用实际电池，无 on_load 注电。地表/区块删除和无事件的外部销毁通过 object-destroy 注册清理。辅助实体被其他 Mod 移除时在下一次桶更新修复，缺失电池按空电处理。检测到辅助实体与主建筑地表或位置不同，会重建辅助实体并转移现存实际储能；主阵营变化时同步辅助阵营。

原生克隆只复制主实体，克隆出来的辅助实体立即删除；新克隆的主实体建立自己的空电辅助集合。无事件创建的 Mod 必须 `raise_built=true` 或调用原生 script-raised 建造事件；运行中完全无事件的外部创建不会被全图周期扫描发现，配置变更时会补登记为空电。跨地表移动和第三方大规模克隆/搬运的全部组合未做穷尽测试。

## 验证与限制

参见 `tests/TEST-RESULTS.md`，内含 20 项验收映射、实测功率、伤害到达时间及未实测项目。`tests/run.py` 可以使用官方 headless binary 重新运行原型断言、核爆场景及原生机器人生命周期测试。测试 Mod 不会自动启用；正常安装主包不会运行测试。

```sh
python3 tests/run.py --factorio /path/to/factorio/bin/x64/factorio --work /path/to/fresh/work/na-tests
lua5.2 tests/gui-unit.lua control.lua
```

满电核爆有 200,000 个真实伤害弹道，并可能在数秒内引发无限制的额外连锁；无法保证稳定 60 UPS。本次测试曾测得单次更新超过 1 秒的停顿。保持破坏密度有实际成本，不能通过把伤害乘 100 来消除。测试未发生 Mod Lua 错误不等于保证任意硬件、无限连锁或任意 Mod 组合不会耗尽资源。原型结构不匹配时会在加载阶段明确报错，优先保证原版可运行而不是猜测未知核爆布局。

尚未完成图形客户端 GUI 点击/外观验收、实际多人会话及全量其他 Mod/DLC 兼容性测试。纯原版 2.0.77、2.1.21 是本次实际测试目标。UI 的确认状态机经过 API doubles 逻辑测试，不能把它声称为图形客户端验收。

## 官方依据

- 原版数据：下载的官方 Factorio 2.0.77 与 2.1.21，`data/base/prototypes/entity/atomic-bomb.lua`、`entities.lua`、`recipe.lua`、科技原型。
- [官方原版数据仓库](https://github.com/wube/factorio-data)
- [LuaEntity：energy、health、电路读取、克隆与事件](https://lua-api.factorio.com/latest/classes/LuaEntity.html)
- [LuaWireConnector](https://lua-api.factorio.com/latest/classes/LuaWireConnector.html)
- [LuaConstantCombinatorControlBehavior](https://lua-api.factorio.com/latest/classes/LuaConstantCombinatorControlBehavior.html)
- [LuaLogisticSection](https://lua-api.factorio.com/latest/classes/LuaLogisticSection.html)
- [建造、机器人、死亡等事件](https://lua-api.factorio.com/latest/events.html)
- [ItemToPlace / placeable_by](https://lua-api.factorio.com/latest/types/ItemToPlace.html)
- [自动地图标签](https://lua-api.factorio.com/latest/classes/LuaForce.html#add_chart_tag)

## English quick guide

Install the ZIP matching Factorio 2.0 or 2.1; no Space Age dependency. Research Atomic Bomb to unlock the recipe (20 processing units, 20 explosives, 60 uranium-235 in the tested base game). The station is a real 36 GJ, 5 MW-in / 5 MW-out native accumulator plus a substation and native 300 kW radar. The factory item starts fully charged; mining always returns the used item, which places an empty station. Mining discards remaining charge and never detonates. Factory and used stations look and behave alike but their blueprints request their respective items; robots cannot substitute one item type for the other.

Select the station and press Ctrl+Shift+N to inspect or arm a manual detonation, then confirm within 10 seconds. Red/green circuits output E (MJ), H (health), P (percent); a positive combined D detonates. Telemetry and circuit polling refresh at most every 30 ticks. Death triggers a native nuclear explosion; normal mining does not. Friendly buildings and other stations can be destroyed and trigger uncapped chain reactions.

Theoretical multiplier is `1 + 9 × charge_fraction`; actual explosions use the nearest 1% tier. Damage wave radii scale by M and projectile populations by M², preserving base per-impact damage, local radius and native propagation speed. Full charge creates 200,000 damaging projectiles. Visual populations are not multiplied by 100. Severe UPS drops are expected. See the test report for real headless results and the remaining graphical-client, multiplayer and compatibility checks. Version 2.1.21 was obtained from the official experimental channel; only 2.0.77 was verified as stable in this session.
