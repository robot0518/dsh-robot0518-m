# FLAC 封面与转码红线

> 本文从主文件「批量与格式」分出；转码/嵌封面分支才需要读。

- m4a 封面嵌入实测由 yt-dlp 自带 mutagen 完成；flac 嵌封面若报 mutagen 错误，改用 ffmpeg 手动（`attached_pic`）：

  ```powershell
  & "$env:LOCALAPPDATA\Programs\yt-dlp\ffmpeg.exe" -y -i "<音频>" -i "<封面>" `
    -map 0:a -map 1:v -c copy -disposition:v attached_pic `
    -metadata title="<标题>" -metadata artist="<UP主>" "<输出.flac>"
  ```

- 追加 `--audio-format mp3`/`m4a` 会破坏无损：mp3 对 AAC 源是二次有损转码，m4a 遇 FLAC 源被强制转 AAC。要兼容格式先无损落盘，再另存转码副本，不覆盖原件。
