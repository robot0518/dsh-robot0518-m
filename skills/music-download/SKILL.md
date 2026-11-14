---
name: music-download
description: B站无损音乐下载：Hi-Res FLAC 优先、AAC 兜底，自动写标签、嵌封面、记账。Use when the user asks 下载这首歌/下首歌/无损音乐/B站音乐/Hi-Res/歌手歌名批量下载，gives a bilibili 音乐或歌单 URL, or reports 下载的音乐没有封面/没有歌手名/音质不对.
---

# B站无损音乐下载

## 环境（事实源，先读）

- `yt-dlp.exe`/`ffmpeg.exe`/`ffprobe.exe` 固定在 `%LOCALAPPDATA%\Programs\yt-dlp\`；Agent 会话的 PATH 是启动时旧值，**shell 内一律全路径调用**。
- 本机默认 shell 是 PowerShell 5.1：没有 `??` 和三元运算符，用 `if/else`。
- 输出目录固定 `E:\Mars\AI_workspace\downloads\music\`；账本 `downloaded.music.txt`。与视频 `downloaded.txt`、音频 `downloaded.audio.txt` 是三本独立账：同一视频下过 mp4 不拦音乐任务。
- Cookie：`E:\Mars\AI_workspace\bilibili.cookies.txt`。失效症状与处置见「cookie 失效」分支。

## 无损的边界（先读，决定报告话术）

- B站只有 **Hi-Res 流（format id 30251）是真 FLAC 无损**，需同时满足：内容本身提供 Hi-Res + cookie 登录态 + **账号大会员生效中**（nav API 看 `vipStatus=1`；`vipType` 只是历史开通记录，不作数）。
- 工具事实（yt-dlp 2026.08 / master 源码验证）：B站提取器请求 `fnval=4048`，不含 4096（Hi-Res）位——**纯 yt-dlp 永远拿不到 FLAC**，真无损必须走 yutto 分支，别在 yt-dlp 上找开关。
- 无 Hi-Res 时音频顶格是 204k AAC（30280）。「无损提取」= 源编码 stream copy 不二次转码：AAC 源落盘 m4a 是"没更差"，不是"更清晰"。向用户报告时如实区分：`flac` = 真无损到手；`aac` = 该内容无 Hi-Res，已是账号可见最高音质。
- 账号无权限（无大会员、内容未授权）服务器不发流，任何工具都下不了，如实告知。

## 主流程（单链接）

1. 确认 URL 即可开工；输出目录与音质策略由本 skill 默认值承担，用户没提就不再问。
2. 执行（音质自动顶格、命名 `UP主 - 标题 [BV号]`、写 title/artist 标签、嵌封面、记账）：

   ```powershell
   & "$env:LOCALAPPDATA\Programs\yt-dlp\yt-dlp.exe" -f bestaudio -x --no-mtime `
     --embed-metadata --embed-thumbnail --parse-metadata "uploader:(?P<artist>.*)" `
     -P "E:\Mars\AI_workspace\downloads\music" -o '%(uploader)s - %(title)s [%(id)s].%(ext)s' `
     --download-archive "E:\Mars\AI_workspace\downloads\music\downloaded.music.txt" `
     --cookies "E:\Mars\AI_workspace\bilibili.cookies.txt" `
     "<URL>"
   ```

   - `-f bestaudio` 顶格是 30280（204k AAC）；`-x` 缺省 stream copy：AAC→.m4a。要真无损 FLAC 直接走「Hi-Res 真无损分支（yutto）」，yt-dlp 路径不出 FLAC。
3. 完成标准：ffprobe 验出 codec、码率、title/artist 标签、封面流（mjpeg/png 视频流即封面）四件齐，并向用户报告 codec 属哪档（flac=真无损 / aac=兜底）：

   ```powershell
   & "$env:LOCALAPPDATA\Programs\yt-dlp\ffprobe.exe" -v error `
     -show_entries format=bit_rate:format_tags=title,artist:stream=codec_name,codec_type `
     -of default=noprint_wrappers=1 "<文件>"
   ```

4. 长批量（预计超过 1~2 分钟）挂进度窗，用户才有可见进度：

   ```powershell
   & 'E:\Mars\AI_workspace\tools\ytdlp-progress.ps1' -Url '<URL>' `
     -OutDir 'E:\Mars\AI_workspace\downloads\music' `
     -Archive 'E:\Mars\AI_workspace\downloads\music\downloaded.music.txt' `
     -ExtraArgs @('-f','bestaudio','-x','--embed-metadata','--embed-thumbnail',`
       '--parse-metadata','uploader:(?P<artist>.*)')
   ```

   （进度脚本默认 `-Cookies` 已指向本机 cookie，无需重复传。）

## Hi-Res 真无损分支（yutto）

前提即「无损的边界」三条，缺一不可。缺会员时 B站只回 320kbps 及以下 AAC，如实告知后改走主流程。

1. 安装（首次；本机 Python 3.12 可用，实测 yutto 2.3.1）：`python -m pip install yutto`。
2. SESSDATA 从 cookie 文件读进变量传给 yutto（**只经变量流转，终端/日志/回答一律不回显**）：

   ```powershell
   $sess = ((Get-Content 'E:\Mars\AI_workspace\bilibili.cookies.txt' |
     Where-Object { $_ -like "*`tSESSDATA`t*" } | Select-Object -First 1) -split "`t")[-1]
   $yutto = Join-Path (python -c "import sysconfig; print(sysconfig.get_path('scripts'))") 'yutto.exe'
   ```

3. 执行（单 P 视频用 `?p=N` 限定——不带 p 的多 P/合集会**全量下载所有分 P**）：

   ```powershell
   & $yutto -c $sess --audio-only -aq 30251 --output-format-audio-only flac `
     --no-danmaku --no-subtitle `
     --ffmpeg-path "$env:LOCALAPPDATA\Programs\yt-dlp\ffmpeg.exe" `
     -d 'E:\Mars\AI_workspace\downloads\music' `
     'https://www.bilibili.com/video/<BV号>?p=1'
   ```

4. **假无损警报**：日志出现「无法直接封装 mp4a 音频流，已自动转换为 flac」= B站没给 Hi-Res，yutto 把 AAC **转码**成了假 FLAC——立即删除该文件，改走主流程拿 m4a（真话优于假无损）。真 Hi-Res 的标志是音质清单里出现 `30251`/FLAC 档位。
5. 收尾：yutto 不写 title/artist 标签、不嵌封面、不认 `downloaded.music.txt`——产物用下节 ffmpeg 命令补标签封面，成功后向账本 `Add-Content` 追加该 BV 行防重下。

## cookie 失效（分支）

- 症状：命令行明明带了 `--cookies`，日志仍出现 `you have to become a premium member ... Use --cookies`；`-F` 只见 30216/30232/30280 三档 AAC；大会员视频格式同样缺。典型原因：B站在用户改密/退出登录/风控时提前作废 SESSDATA，文件里的过期日期不作数。
- 验证（不暴露 cookie 内容）：

  ```powershell
  $nav = curl.exe -s -b "E:\Mars\AI_workspace\bilibili.cookies.txt" "https://api.bilibili.com/x/web-interface/nav" | ConvertFrom-Json; "isLogin=$($nav.data.isLogin)"
  ```

  `isLogin=False` 即失效。
- 处置：请用户在已登录的 Edge 里用 **Cookie-Editor** 扩展（商店 ID `neaplmfkghagebokkhpjpoebhdledlfi`，国内可达；商店里同名 "get cookies txt" 有恶意前科，只认 Cookie-Editor）导出 Netscape 格式，覆盖更新 `bilibili.cookies.txt`，重跑上面的验证直到 `isLogin=True`。`--cookies-from-browser edge` 在本机是死路（DPAPI 应用绑定加密，必报解密失败），不要尝试。
- 红线：cookie 文件等于账号钥匙——不读取内容、不在终端输出、不外传、不复制。

## 批量入口（reference）

- 收藏夹（`favlist` URL）、合集、UP主空间页 URL 直接传入主流程同一命令；大列表追加 `--sleep-interval 2 --max-sleep-interval 5` 防风控，并挂进度窗跑。
- 已实测 `bilisearch`（yt-dlp 站内搜索）被 B站 412 风控拒绝——找歌先用网页搜索拿到具体视频 URL，再走本 skill。
- 账本是进程启动时的内存快照：同一批量任务同一时间只跑一个；**绝不**对同一 URL 并发起两个 yt-dlp（同名 `.part` 交错写坏是唯一损坏场景）。
- 升音质重下（旧账本记了 AAC、现在 cookie 有效想拿 FLAC）：先删 `downloaded.music.txt` 里对应行，只许 `Add-Content` 追加、禁止整文件重写。

## FLAC 封面与转码红线（reference）

- m4a 封面嵌入实测由 yt-dlp 自带 mutagen 完成；flac 嵌封面若报 mutagen 错误，改用 ffmpeg 手动（`attached_pic`）：

  ```powershell
  & "$env:LOCALAPPDATA\Programs\yt-dlp\ffmpeg.exe" -y -i "<音频>" -i "<封面>" `
    -map 0:a -map 1:v -c copy -disposition:v attached_pic `
    -metadata title="<标题>" -metadata artist="<UP主>" "<输出.flac>"
  ```

- 追加 `--audio-format mp3`/`m4a` 会破坏无损：mp3 对 AAC 源是二次有损转码，m4a 遇 FLAC 源被强制转 AAC。要兼容格式先无损落盘，再另存转码副本，不覆盖原件。
- 版权边界：仅限个人离线使用，不协助二次传播。
