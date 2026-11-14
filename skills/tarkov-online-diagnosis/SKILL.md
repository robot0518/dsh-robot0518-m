---
name: tarkov-online-diagnosis
description: >
  逃离塔科夫（Escape from Tarkov，含 PvE 模式）联机诊断，本机专属。塔科夫联机卡住——
  卡在"正在加载配置文件..."、登录后无限转圈、上不去、连不上后端、报 403——或 BSG 启动器
  （BsgLauncher）崩溃、闪退、白屏、打不开时使用，启动器问题走其中的启动器分支。不适用于：
  游戏内帧数/掉帧、游戏本体 EscapeFromTarkov.exe 闪退（那是性能与崩溃问题）、其他游戏的联机问题。
---

# Tarkov Online Diagnosis

流程：定位安装与最新会话 → 读会话日志分类卡点 → 游戏外探测对照出口 IP → 扫历史判断复发 → 结论。全程只读：不动游戏文件、不改配置、不杀进程、不提交任何带账号凭据的请求（探测一律匿名 GET）。

## 铁律

- **先读到日志里的实际卡点再下结论。** "正在加载配置文件"字面像本地档案损坏，本机实测从来不是——不要凭字面猜。
- **永远不建议"直连试试"。** 已实测：裸中国 IP 访问 BSG 任何端点直接 403（地域封锁页）。加速器是必选项，不是可选项。
- **发现优先于硬编码。** 安装路径、客户端版本号都会变（Steam 自动更新）；下面的"已知起点"只是起点，每次先用脚本核实。
- **注册表和快捷方式不可信。** 它们指向已删除的目录（见"陷阱"），只用于发现候选，必须 Test-Path 验证。

## 背景知识（30 秒版）

PvE 登录链路：客户端依次请求 `gw-pvp.escapefromtarkov.ru/client/game/mode` → `gw-pve/client/game/start` → 版本校验 → 语言包 → `client/game/config` → `client/game/token/issue` → **`lobby.escapefromtarkov.ru/router?vhost=pve`（lobby 入口，风险最高的一跳）** → WebSocket。前几跳走 BSG 网关（防护宽松），lobby 是反 DDoS 防护最重的边缘（nginx ngx_stub 模块），共享加速器出口 IP 在这一跳最容易被挑战。任何一跳拿不到响应，客户端就无限退避重试、不报错，画面停在加载文案。

客户端日志在 `<安装>\build\Logs\log_<日期>_<时间>_<客户端版本>\` 下，每场会话一个目录：

- `backend_000.log` — 每个后端请求的 URL/耗时/状态码，**判断卡点的主文件**
- `errors_000.log` — 错误与堆栈
- `ping_000.log` — WebSocket 连接结果
- `output_000.log` / `application_000.log` — 客户端输出与设置
- 文件名带 `<时间戳>_<版本> ` 前缀，匹配用通配符 `*backend_*.log`，别用精确名

## 已知起点（2026-11-14 核实，仍需每次验证）

- 现役安装：`C:\SteamLibrary\steamapps\common\Escape from Tarkov\build\`
- 陷阱（残留死链，勿信）：注册表卸载项指向 `C:\EFT 4.0\Install_EFT`、开始菜单快捷方式指向 `C:\SPT-EFT-bilibili habi-3.11-Sain-1.2.0`——目录已不存在。
- 加速器：雷神（leigod），5 个常驻进程；本机无全局代理（ProxyEnable=0）、hosts 无 tarkov 条目。

## Step 1+2 上下文、定位、读日志（一个脚本）

从宿主当前加载的 Skill 位置取得实际绝对目录并设为 `SKILL_DIR`，然后：

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$SKILL_DIR/scripts/diag_context.ps1"
```

输出：游戏/BattlEye/加速器/VPN 进程、安装定位（验证过的）、系统代理与 hosts、网卡、近 7 天崩溃转储（CrashDumps，按应用汇总，识别这类"天天崩但没人看"的常驻问题）、**最新一场会话的日志尾部**（backend 前 45 行 + 后 45 行、errors 60 行、ping 20 行、output 60 行）和本场 403 计数。

## 判读规则表

| 日志证据 | 含义 | 处置 |
|---|---|---|
| backend：`lobby.../router?vhost=pve` 403，错误页 Content-Length 1079，带 `Set-Cookie: ngx_stub_request_ip=<IP>`；同会话 gw-pve 各请求 200 | 反 DDoS 模块在挑战加速器出口节点（IP 信誉/限流），非账号、非本地问题 | 让用户**换雷神节点**再试；或等 20~30 分钟重开（历史多次自愈）。若某节点一周中招多次，建议用户固定换线或向加速器客服反馈 |
| 游戏外探测（Step 3）也 403，页面 Content-Length 3136 样式化 HTML、无 ngx_stub cookie | 地域封锁页：该请求走的是中国裸 IP | 边界条件不是故障：确认加速器没把这条流量代理到；重申必须走加速器 |
| gw-pve 的 keepalive/start 也失败或超时 | 加速器隧道断了或 BSG 服务端整体故障 | 检查加速器进程与节点；查「外部状态源」确认是否服务器侧事件 |
| backend 全部 200 但客户端仍卡 | 卡点不在后端 | 读 output_000.log / errors_000.log 找客户端异常堆栈，按堆栈另行诊断 |
| ping_000.log：`WS Connection failed: Failed to get WS location` | lobby 没给出 WS 位置 | 通常是 router 403 的连带症状，按第一行处置 |

`ngx_stub_request_ip` 的值 = BSG 边缘看到的出口 IP：中国 ISP 段 = 直连（会被地域封锁）；俄罗斯机房段 = 雷神出口。与 Step 3 探到的真实本机 IP 对照即可判断哪条流量走了隧道。

## 外部状态源

- 官方服务状态页：<https://status.escapefromtarkov.com>（server issues 计数 + 近 7 天公告）
- 用户崩溃报告：<https://downdetector.com/status/escape-from-tarkov>
- 官方公告（技术更新/维护）：<https://x.com/tarkov>

## Step 3 游戏外探测（对照出口 IP）

```bash
PYTHONIOENCODING=utf-8 "<捆绑Python路径>" "$SKILL_DIR/scripts/probe_tarkov.py"
```

匿名 GET 四个端点：lobby router（预期 403）、gw-pve config（对照）、api.ipify.org（对照，可能被重置）、myip.ipip.net（真实公网 IP 与归属）。脚本对 403 做分类（stub-challenge / 地域封锁页）。**Python 路径经 load_workspace_dependencies 获取，不要硬编码。**

## Step 4 历史复发判断

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$SKILL_DIR/scripts/scan403.ps1"
```

逐场输出 `ok=N 403=M`。判读模式：

- **偶发爆发**（单场 403 几次到一百多、其余场 0）→ 节点限流，换会话/换时段常自愈 → 按规则表第一行处置，并向用户出示"上次 XX 日也这样、XX 分钟后那场就好了"的历史对照。
- **连续多场、换节点后仍 403** → 升级判断：先查「外部状态源」确认是否 BSG 侧事件；状态页正常且换节点无效时才考虑账号问题（走 BSG 支持渠道），不要继续让用户换节点瞎试。

## 结论格式

对话里按固定顺序给：卡点（哪一步、什么错误码/页面）→ 根因分类（节点限流 / 地域封锁边界 / 服务端故障 / 本地）→ 处置建议排序 → 历史对照（是否复发、上次怎么恢复的）。用户通常只看结论段，证据放其后。

## 机器事实（DSH 沙箱，写脚本前必读）

- 沙箱内 Windows TLS（schannel）不可用：`Invoke-WebRequest`/curl 报 SEC_E_NO_CREDENTIALS。网络探测一律用捆绑 Python（OpenSSL 栈）。
- 控制台编码 GBK：PS 脚本输出只用 ASCII 标记；Python 设 `PYTHONIOENCODING=utf-8`。
- `Get-Process` 看不到提权进程：加速器进程 PATH 为空/Start 为空 ≠ 没在跑，看到名字就算在。
- 复杂操作写成 .ps1/.py 按路径执行，不要经 `cmd //c` 内联（长命令会参数断裂）。
- 客户端版本号会随 Steam 更新变化（日志目录名里的 `_1.3.0.2.48779` 一类后缀是版本，别拿它做精确匹配）。

## 分支：启动器崩溃（BsgLauncher）

启动器崩溃、闪退、白屏的报告进来时读 [references/launcher-crash.md](references/launcher-crash.md)：已知结案（libcef page_discarder 断言 bug，工单 #48436378）的签名比对、dump 取证与新断言定性、启动器日志位置与工单跟进通道。
