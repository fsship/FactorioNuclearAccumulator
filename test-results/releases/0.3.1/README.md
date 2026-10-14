# 0.3.1 自动修复实测

2026-10-14，分别使用最终 0.3.1 ZIP 在 Factorio 2.0.77 stable 和 2.1.21 experimental 运行全部五个套件。两个目标都通过；安装包 SHA-256、实测回血值和测试范围见 [results.json](results.json)。

- tank 验证真实伤害、完整 600 tick 冷却、再次受伤打断、约 50 HP/秒、原生自动激光及驾驶射击期间暂停、原生抗性完全挡伤仍暂停、生命值上限、独立车辆和致死清理。
- 每个目标用私有 127.0.0.1 服务器保存两次，然后停止进程、独立重新读取：tick 1200 在修复冷却期间（tank/resume.log）；tick 2100 在实际回血期间（tank/resume-repairing.log）。恢复计时正确，没有离线回血。
- acceptance/lifecycle/tags/queue 重新验证核能蓄电站与核爆；tags/queue 的真实保存读取也再次通过。
- gui-unit.log 仅为现有 GUI API doubles 检查；static-check.log 是 Lua 5.2、JSON/Python、ZIP 一致性、本地化和历史校验值检查。

真人客户端本地/远程及乘客射击、实际多人、品质/DLC 或第三方 Mod 组合尚未执行。日志内的 benchmark 耗时来自并行功能测试，不是严格性能对照。2.1 本次使用 experimental，不声称验证 2.1 稳定发行版。
