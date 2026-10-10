# 共享测试入口

所有当前测试仅保留一份，运行源码位于仓库根目录 `mod/`。测试运行器和发布脚本共同使用 `scripts/package.py` 及 `scripts/build-targets.json`，不会改写源清单。

从仓库根目录执行：

```sh
python3 tests/run.py --factorio /path/to/factorio/bin/x64/factorio --work work/new-test-run
python3 tests/run.py --factorio /path/to/factorio/bin/x64/factorio --mod-zip releases/factorio-2.0/nuclear-accumulator_0.2.4.zip --work work/new-zip-run
lua5.2 tests/gui-unit.lua mod/control.lua
```

不提供 `--mod-zip` 时，自动检测游戏是 2.0 或 2.1，并从 `mod/` 生成相应 ZIP。提供 ZIP 时直接安装该文件，检查其清单与游戏版本匹配。`--suite` 可选 `acceptance`、`lifecycle`、`tags`、`queue` 或默认的 `all`。

- acceptance：真实电网、信号、0/50/100% 核爆、友军伤害、传播及二次爆炸计数。
- lifecycle：真实机器人、回收余电、蓝图、实际采矿产出、雷达扫描、克隆和清理。
- tags：精确/零标签、物流、重复回收、真正配方制造、蓝图线路，以及回收后跨进程保存/读取。
- queue：全局 1,024 调度额度、精确总数、阵营合并、地表删除和爆炸中途保存/读取。

tags 和 queue 的保存测试短暂运行只绑定 127.0.0.1 的私有服务器，需要本地 socket 权限。其他两套件不启动服务器。工作路径必须全新，已有套件目录会拒绝覆盖；源码及玩家已有游戏存档均不受影响。

GUI 脚本是现有 API doubles 逻辑检查，不是图形客户端验收。真实客户端步骤见 [MANUAL-TESTS.md](MANUAL-TESTS.md)。历史版本的旧测试脚本交给 Git 保存；原始证据位于 [test-results/](../test-results/README.md)。
