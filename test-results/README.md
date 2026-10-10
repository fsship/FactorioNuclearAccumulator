# 测试证据归档

本目录保存原始运行证据，不包含第二份 Mod 源码。2026-10-10 整理目录时，118 个既有日志/结果文件按原字节迁移，旧安装 ZIP 保持原样。

- `releases/0.1.0/`～`releases/0.2.3/`：原版本目录下的 `tests/logs/` 内容。
- `experiments/ammo/`、`experiments/tags/`：历史弹匣/物品标签实验日志。
- [history-paths.json](history-paths.json)：旧路径、现路径、SHA-256 和对应 Git 源码快照，可逐文件核对迁移。
- `releases/0.2.4/`：单一源码结构整理后新执行的验证记录，按游戏目标分开。

历史 Mod 源码、旧测试脚本和报告均可在 Git 快照 `a67c4ca` 找到，旧 ZIP 保留在仓库 `releases/`。查看文件或重跑旧性能对照时使用独立工作树：

```sh
git show a67c4ca:nuclear-accumulator_0.1.0/control.lua
git worktree add --detach work/history a67c4ca
```

历史日志里的原绝对路径、版本和结果保持不变，不代表当前目录仍有那些源码副本。当前运行和构建只使用 `mod/`、`tests/`、`scripts/`。故意失败的弹匣/原型上限探针仍标为失败，历史升级测试不意味着现版本实现了旧存档迁移。
