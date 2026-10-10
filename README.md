# Nuclear Accumulator

完整 Factorio Mod，原版游戏即可运行，无需 Space Age。当前版本 **0.2.4** 使用一份源码，为 Factorio 2.0 和 2.1 生成不同清单的安装包。

建筑具有真实 36 GJ 原生电池、5 MW 充放电限制、配电站、雷达和电路信号。物品标签保存精确回收电量，包括零值；蓝图统一请求同一种物品。GUI 用原生进度条显示剩余电量。核爆保留原生空间分布与传播，满电共 200,000 个伤害弹道，按全局每 tick 最多 1,024 个调度，支持连锁和中途保存。

- [Factorio 2.0.77 安装包](releases/factorio-2.0/nuclear-accumulator_0.2.4.zip)
- [Factorio 2.1.21 experimental 安装包](releases/factorio-2.1/nuclear-accumulator_0.2.4.zip)
- [使用说明与功能限制](mod/README.md) · [校验值](releases/SHA256SUMS.txt)

两个 ZIP 同名，下载目录区分游戏目标。只安装对应游戏版本的一个 ZIP。

## 开发结构

```text
mod/            唯一运行源码与默认 info.json
tests/          共享测试场景和运行器
scripts/        打包脚本及目标清单配置
releases/       当前与历史安装包
test-results/   原始日志和结果，按版本/目标归档
docs/           需求、决策和报告
work/           Git 忽略的临时文件及测试存档
```

版本号只在 `mod/info.json` 修改。两版目标通过 `scripts/build-targets.json` 调整 `factorio_version` 和 `dependencies`，不创建新的源码目录。完整结构与历史恢复方式见 [REPOSITORY-STRUCTURE.md](docs/REPOSITORY-STRUCTURE.md)。

```sh
python3 scripts/package.py
python3 scripts/package.py --target 2.1
python3 tests/run.py --factorio /path/to/factorio/bin/x64/factorio --work work/new-test-run
lua5.2 tests/gui-unit.lua mod/control.lua
```

打包默认生成两个目标并更新 SHA-256；测试自动选择游戏目标，使用同一打包模块。也可通过 `--mod-zip` 验收指定发布 ZIP。测试套件、权限和图形客户端步骤见 [tests/README.md](tests/README.md)。

## 历史与验证

旧源码副本及实验代码在 Git 快照 `a67c4ca` 保留，当前树只维护一份运行源码。旧 ZIP 未重打包，118 个历史证据文件原样移到 [test-results/](test-results/README.md)，附逐文件路径/校验对照。

- [目录重构验证](docs/REPOSITORY-STRUCTURE.md)
- [标签整合历史实测](docs/TAG-INTEGRATION.md) · [电量携带机制实验](docs/CHARGE-STATE-TEST-RESULTS.md)
- [核爆性能对照](docs/WAVE-OPTIMIZATION.md) · [进度条更新](docs/UI-PROGRESS.md)
- [最初验收](docs/TEST-RESULTS.md) · [原始需求](docs/USER_SPEC.md)
- [独立评审](docs/RELEASE-REVIEW.md) · [已确认决策](docs/DECISIONS.md)

雷达目前使用共享电网；严格仅本电池供能及固定外部功率保留仍待实现。真实图形客户端、实际多人和任意第三方 Mod 组合尚未完整验收。旧存档迁移按用户明确要求不在范围内；大型核爆仍可能降低 UPS。游戏程序和原版资源不随仓库分发。
