# bsg_crash_forensics.ps1 - BsgLauncher crash forensics (read-only, ASCII output)
# dump inventory + event log signature + launcher versions + daily log tail
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Output "=== [A] CRASH DUMP INVENTORY (14 days) ==="
$cd = "$env:LOCALAPPDATA\CrashDumps"
$dumps = Get-ChildItem $cd -File | Where-Object { $_.Name -match '^BsgLauncher' -and $_.LastWriteTime -gt (Get-Date).AddDays(-14) } | Sort-Object LastWriteTime
foreach ($d in $dumps) {
  Write-Output ("DUMP: {0}  {1}KB  {2}" -f $d.Name, [math]::Round($d.Length/1KB), $d.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
}
Write-Output ("total: " + $dumps.Count)

Write-Output "=== [B] EVENT LOG: Application Error / .NET (14 days, BsgLauncher) ==="
$events = Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000,1026; StartTime=(Get-Date).AddDays(-14)} | Where-Object { ($_.Properties[0].Value -as [string]) -match 'BsgLauncher' -or $_.Message -match 'BsgLauncher' }
if (-not $events) { Write-Output "(no app-error events found)" }
foreach ($e in $events) {
  Write-Output ("EVENT time={0} id={1}" -f $e.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'), $e.Id)
  $p = $e.Properties
  if ($e.Id -eq 1000) {
    Write-Output ("  app={0} ver={1}  module={2} ver={3}" -f $p[0].Value, $p[1].Value, $p[3].Value, $p[4].Value)
    Write-Output ("  excCode={0} offset={1} pid={2}" -f $p[6].Value, $p[7].Value, $p[8].Value)
    $report = $p[11].Value; if ($report) { Write-Output ("  reportPath={0}" -f $report) }
  } else {
    $msg = ($e.Message -split "`n" | Select-Object -First 6) -join ' | '
    Write-Output ("  dotnet: " + $msg)
  }
}

Write-Output "=== [C] LAUNCHER INSTALLS (two copies!) ==="
$lc = @('C:\Battlestate Games\BsgLauncher\BsgLauncher.exe', 'C:\SteamLibrary\steamapps\common\Escape from Tarkov\launcher\BsgLauncher.exe')
foreach ($l in $lc) {
  if (Test-Path $l) {
    $v = (Get-Item $l).VersionInfo
    Write-Output ("LAUNCHER: {0}  ver={1}  (mod {2})" -f $l, $v.ProductVersion, (Get-Item $l).LastWriteTime.ToString('yyyy-MM-dd'))
  } else { Write-Output ("(missing): " + $l) }
}
Write-Output "NOTE: Steam launches the bundled one (SteamLibrary\...\launcher\); old standalone never gets used."

Write-Output "=== [D] LAUNCHER OWN LOGS (LOCALAPPDATA\Battlestate Games\BsgLauncher\Logs) ==="
$lld = "$env:LOCALAPPDATA\Battlestate Games\BsgLauncher\Logs"
if (Test-Path $lld) {
  $newest = Get-ChildItem $lld -Filter 'BSG_Launcher_*.log' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($newest) {
    Write-Output ("LOG: {0}  {1}KB  (mod {2})" -f $newest.FullName, [math]::Round($newest.Length/1KB), $newest.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
    Write-Output "--- first 6 lines (session start) ---"
    Get-Content $newest.FullName -TotalCount 6 | ForEach-Object { Write-Output ($_.Substring(0, [Math]::Min(200, $_.Length))) }
    Write-Output "--- last 30 lines (pre-crash activity; crash itself leaves no line) ---"
    Get-Content $newest.FullName -Tail 30 | ForEach-Object { Write-Output ($_.Substring(0, [Math]::Min(220, $_.Length))) }
  }
  $cef = Join-Path $lld 'Cef.log'
  if (Test-Path $cef) {
    Write-Output "--- Cef.log tail 15 ---"
    Get-Content $cef -Tail 15 | ForEach-Object { Write-Output ($_.Substring(0, [Math]::Min(220, $_.Length))) }
  }
} else { Write-Output ("(no launcher log dir): " + $lld) }

Write-Output "=== [E] RUNNING NOW ==="
Get-Process | Where-Object { $_.ProcessName -match 'BsgLauncher|Battlestate' } | ForEach-Object {
  Write-Output ("PROC {0} PID={1} PATH={2}" -f $_.ProcessName, $_.Id, $(if ($_.Path) { $_.Path } else { '(hidden)' }))
}

Write-Output "=== DONE ==="
