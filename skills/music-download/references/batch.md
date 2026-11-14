# 批量入口（收藏夹 / 合集 / UP主）

> 本文从主文件「批量与格式」分出；批量分支才需要读。

- 收藏夹（`favlist` URL）、合集、UP主空间页 URL 直接传入主流程同一命令；大列表追加 `--sleep-interval 2 --max-sleep-interval 5` 防风控，并挂进度窗跑。
- 已实测 `bilisearch`（yt-dlp 站内搜索）被 B站 412 风控拒绝——找歌先用网页搜索拿到具体视频 URL，再走本 skill。
- 账本是进程启动时的内存快照：同一批量任务同一时间只跑一个；**绝不**对同一 URL 并发起两个 yt-dlp（同名 `.part` 交错写坏是唯一损坏场景）。
- 升音质重下（旧账本记了 AAC、现在 cookie 有效想拿 FLAC）：先删 `downloaded.music.txt` 里对应行，只许 `Add-Content` 追加、禁止整文件重写。
