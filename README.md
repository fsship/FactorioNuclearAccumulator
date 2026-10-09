# Nuclear Accumulator

完整 Factorio Mod 源码、安装 ZIP 与真实引擎测试结果。

最新版本采用分帧释放的原生核爆：伤害数量与密度保持不变，每 tick 全局最多调度 1,024 个新伤害弹道，连锁爆炸共享队列。两版实测单 tick 峰值下降约 89%–90%，外圈伤害仍逐渐传播。[完整性能与验收报告](docs/WAVE-OPTIMIZATION.md)。

- [Factorio 2.0.77：0.1.2 安装包](releases/nuclear-accumulator_0.1.2.zip)，[源码与使用说明](nuclear-accumulator_0.1.2/README.md)。
- [Factorio 2.1.21：0.1.3 安装包](releases/nuclear-accumulator_0.1.3.zip)，[源码与使用说明](nuclear-accumulator_0.1.3/README.md)。2.1.21 为本次取得的 experimental 版本。
- `nuclear-accumulator_0.1.0/`、`nuclear-accumulator_0.1.1/` 与对应 ZIP 保留为历史基线，可运行前后对照测试。
- [电量携带机制实验报告](docs/CHARGE-STATE-TEST-RESULTS.md)，`charge-state-tests/` 包含弹匣与 item-with-tags 的源码、测试和日志。
- [最初验收结果](docs/TEST-RESULTS.md)，[原始开发需求](docs/USER_SPEC.md)。
- [独立评审与未决事项](docs/RELEASE-REVIEW.md)、[已确认决策](docs/DECISIONS.md)。

0.1.x 版本采用首次满电、回收后为空电的物品区别机制，避免重复拆装免费获得能量；回收不保留余电。精确余电的标签实验尚未合并，不能直接当作现有版本升级包。严格雷达本电池供能和约 4.7 MW 外部保留方案仍待独立实现验收，当前候选更新继承共享电网雷达。大型核爆仍可能降低 UPS，完整限制与复现方式见对应报告。

游戏程序和原版资源不随仓库分发。
