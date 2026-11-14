# dsh-robot0518-m — robot0518 的 DSH skill 收录市场

DeepSeek Harness 插件：把自产 skill **随包收录**，经 [dsh-m](https://github.com/iasiv5/dsh-m) 市场安装、升级、卸载；装完插件，收录的 skill 通过 `ctx.skills` 全局可用（模型目录与 `skill` 工具、用户命令都能看到），无需再往 `~/.dsh/skills` 复制文件。

## 收录清单

| skill | 说明 |
|---|---|
| `music-download` | B站无损音乐下载：Hi-Res FLAC 优先、AAC 兜底，自动写标签、嵌封面、记账 |
| `tarkov-online-diagnosis` | 逃离塔科夫联机诊断：卡加载配置文件/403/转圈排障 + BSG 启动器分支 |
| `video-to-notes` | 视频链接转时间戳笔记与报告：转写、字幕、摘要，发布本地/Notion/Obsidian |

收录事实源在 [dsh-skills](https://github.com/robot0518/dsh-skills)（registry + 一键安装脚本的文件级安装通道）；本插件是**第二分发通道**：随包快照、零配置生效。

## 安装（经 dsh-m 市场 · 自定义收录清单）

收录清单是**本仓库的 `registry.json`**（robot0518 自有，不进 iasiv5/dsh-m 默认清单）：

- dsh-m 侧栏「插件市场」→ 设置页 → 自定义收录清单，填入：

  ```
  https://raw.githubusercontent.com/robot0518/dsh-robot0518-m/main/registry.json
  ```

  点「校验并应用」，即时生效；「恢复默认」可随时切回官方清单（注意：自定义清单**整体覆盖**默认清单，不合并）。
- 或贴给 agent：`把 dsh-m 的自定义收录清单设为 https://raw.githubusercontent.com/robot0518/dsh-robot0518-m/main/registry.json 并校验应用，然后安装插件 dsh-robot0518-m`。

## 优先级（rank 语义）

本插件按**随包档 rank 600** 注册：项目 `.dsh/skills`、`.agents/skills`、custom 目录、`~/.dsh/skills`、`~/.agents/skills` 里的**同名本地副本优先**。两边并存时以本地副本为准；只装了本插件的机器上，随包副本直接生效。

## 更新收录的 skill

收录内容是本仓库的随包快照，更新流程：

```sh
node scripts/vendor.mjs                 # 从 ../dsh-skills/skills 同步（--from 可指定别的来源）
# 改 package.json version
git commit && git push
gh release create v<version>            # dsh-m 只跟踪 release/tag；发版后市场里升级
```

`registry.json`（dsh-m v1 schema）是本仓库作为**自定义收录清单**的形态；`scripts/validate-registry.mjs` 本地校验与 dsh-m 同语义。

## License

MIT
