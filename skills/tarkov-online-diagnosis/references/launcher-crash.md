# 分支：启动器崩溃（BsgLauncher）

> 本文从主文件「分支：启动器崩溃」分出；`SKILL_DIR` = 本 skill 根目录（主文件「Step 1+2」节定义），下文 `scripts/` 路径均相对它。

**已知结案（2026-11-15，工单 #48436378，状态开启）**：Steam 库自带启动器 `BsgLauncher.exe 15.1.0.4653`（`<Steam库>\Escape from Tarkov\launcher\`，带 Steam.Sdk/steam_api 集成）的内嵌 CEF 有 Chromium 上游断言 bug：

- 故障模块 `libcef.dll 143.0.9.0`，异常 `0x80000003`（breakpoint），恒定偏移 `0x7b49ffc`
- 断言原文：`FATAL: chrome\browser\performance_manager\mechanisms\page_discarder.cc:50] Check failed: outcome.has_value().`
- 触发规律：游戏运行、启动器后台驻留挨内存压力丢页 → 必崩；游戏本身不受影响
- 处置：进游戏后关启动器；勿切旧版 `C:\Battlestate Games\BsgLauncher`（14.7.2.4271，无 Steam.Sdk，Steam 流程可能断）；修复等 BSG 更 CEF

**新崩溃报告进来时**：

1. 跑 `scripts/bsg_crash_forensics.ps1`：dump 清单、事件日志签名（Event 1000 的 Properties 按索引取值，不受系统语言影响）、两份启动器版本、当日启动器日志尾部
2. 签名与已知一致（libcef / page_discarder / 同偏移）→ 直接引用结案结论与工单号，不重复深查；顺手查工单状态 <https://www.escapefromtarkov.com/support/request>
3. 签名不同 → `PYTHONIOENCODING=utf-8 <捆绑Python> scripts/dump_scan.py <dump路径>` 扫 Chromium CHECK/FATAL 字符串，按新断言重新定性
4. 环境信息（GPU/CPU/RAM/OS/Steam manifest）用 `scripts/bsg_env.ps1`

**启动器日志位置**（2026-11-15 定位）：

- `%LOCALAPPDATA%\Battlestate Games\BsgLauncher\Logs\BSG_Launcher_YYYYMMDD.log`（一天一个）+ `Cef.log`；行格式 `2026.11.14 18:42:28.706 +08:00 [INFO] ...`
- 崩溃时刻本身不留日志行（进程死于断点异常，Serilog 缓冲随之丢失）——只能看最后写入的活动行推断当时操作
- Roaming 下只有 3KB 的 `settings`；CefCache 整个在 LOCALAPPDATA
- **上次教训：先搜 Roaming 扑空了——Battlestate Games 的数据在 LOCALAPPDATA，两处都要探**

**工单跟进**：BSG 回复出现在工单页并发账号邮箱；工单评论区附件限 5 文件 × 3MB，minidump ~70MB 传不了，官方要 dump 需另寻通道。
