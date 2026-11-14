# scan403.ps1 - per-session ok/403 counts across all sessions (read-only, ASCII output)
# usage: powershell -NoProfile -ExecutionPolicy Bypass -File scan403.ps1 [optional-build-path]
param(
  [string]$Build = 'C:\SteamLibrary\steamapps\common\Escape from Tarkov\build'
)
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path $Build)) {
  # fallback: search drive roots for a verified install
  foreach ($root in @('C:\','D:\','E:\')) {
    Get-ChildItem $root -Force -Directory | ForEach-Object {
      $p = Join-Path $_.FullName 'SteamLibrary\steamapps\common\Escape from Tarkov\build'
      if (Test-Path (Join-Path $p 'EscapeFromTarkov.exe')) { $Build = $p }
    }
    if (Test-Path $Build) { break }
  }
}
$base = Join-Path $Build 'Logs'
if (-not (Test-Path $base)) { Write-Output ("FATAL: no Logs dir under " + $Build); exit 1 }

Get-ChildItem $base -Directory | Sort-Object Name | ForEach-Object {
  $bl = Get-ChildItem $_.FullName -Filter '*backend_*.log' -File
  if ($bl) {
    $n403 = 0; $ok = 0
    foreach ($b in $bl) {
      $n403 += (Select-String -Path $b.FullName -Pattern 'responseCode:403' -SimpleMatch).Count
      $ok   += (Select-String -Path $b.FullName -Pattern '<--- Response HTTPS' -SimpleMatch).Count
    }
    Write-Output ("{0}  ok={1}  403={2}" -f $_.Name, $ok, $n403)
  }
}
Write-Output "=== DONE ==="
