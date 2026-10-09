# Nuclear Accumulator

完整 Factorio Mod 源码、安装 ZIP 与真实引擎测试结果。

最新版本已合并 **item-with-tags 精确电量回收**：只有一种建筑物品，首次放置新制品为 36 GJ，回收保存真实电池的焦耳数，再放置恢复余电，显式零标签也能保留。同一张蓝图可使用任意电量的物品；每个物品占一格。按当前尚无在用存档的决定，不实现旧版本迁移。[正式整合与两版最终 ZIP 测试报告](docs/TAG-INTEGRATION.md)。

- [Factorio 2.0.77：0.2.0 安装包](releases/nuclear-accumulator_0.2.0.zip)，[完整源码与使用说明](nuclear-accumulator_0.2.0/README.md)。
- [Factorio 2.1.21：0.2.1 安装包](releases/nuclear-accumulator_0.2.1.zip)，[完整源码与使用说明](nuclear-accumulator_0.2.1/README.md)。2.1.21 为本次取得的 experimental 版本。
- 0.1.0～0.1.3 源码与对应 ZIP 保留为历史基线，可运行前后对照测试。
- [电量携带机制实验报告](docs/CHARGE-STATE-TEST-RESULTS.md)，`charge-state-tests/` 包含弹匣与 item-with-tags 的源码、测试和日志。
- [最初验收结果](docs/TEST-RESULTS.md)，[原始开发需求](docs/USER_SPEC.md)。
- [独立评审与未决事项](docs/RELEASE-REVIEW.md)、[已确认决策](docs/DECISIONS.md)。

分帧核爆继续保留：伤害数量与密度保持不变，每 tick 全局最多调度 1,024 个新伤害弹道，连锁爆炸共享持久队列。此前 0.1.2/0.1.3 对照实测单 tick 峰值下降约 89%–90%，外圈逐渐传播；这组性能数字属于历史性能对照，本次已另行回归最终 0.2.x ZIP 的伤害、连锁和保存/读取。[性能与传播报告](docs/WAVE-OPTIMIZATION.md)。

严格雷达本电池供能和约 4.7 MW 外部保留方案仍待独立实现验收，本次标签整合继承共享电网雷达。图形客户端的真实玩家操作、GUI 点击及多人会话尚未验收；大型核爆仍可能降低 UPS。完整限制与复现方式见对应报告。

安装包可用 `python3 scripts/package.py nuclear-accumulator_0.2.0` 重新生成。运行文件、许可证与 README 包含在安装 ZIP 中，测试脚本和原始日志保留在源码目录。新存档只安装与游戏版本对应的一个包。

游戏程序和原版资源不随仓库分发。
