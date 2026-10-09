# Nuclear Accumulator

完整 Factorio Mod 源码、可安装 ZIP 与真实引擎测试结果。

- `nuclear-accumulator_0.1.0/`：Factorio 2.0.77 基础游戏版本。
- `nuclear-accumulator_0.1.1/`：Factorio 2.1.21 适配版本。
- `releases/`：可安装 Mod ZIP 和电量携带机制实验归档。
- [使用与安装说明](docs/DELIVERY.md)
- [原版本测试结果](docs/TEST-RESULTS.md)
- [电量携带机制测试结果](docs/CHARGE-STATE-TEST-RESULTS.md)
- `charge-state-tests/`：弹匣方案与 item-with-tags 方案的完整实验源码、测试脚本及日志。

原 0.1.x 版本采用首次满电、回收后为空电的物品区别机制，避免重复拆装免费获得能量；回收不保留余电。标签实验已通过两版本原生机器人、物流、蓝图和三次额外循环测试，可携带实际电池的浮点焦耳值。弹匣实验因原生弹量合并导致建筑数量和储能不守恒而未通过。

标签实验尚未验证真实玩家操作及旧存档迁移，不能直接当作旧版本升级包。完整边界见对应测试报告。游戏程序和原版资源不随仓库分发。

原始开发需求保留在 `docs/` 中。
