# diag_context.ps1 - discover install, context, newest session logs (read-only, ASCII output)
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Output "=== [A] GAME / ACCELERATOR / VPN PROCESSES ==="
$pat = 'EscapeFromTarkov|BsgLauncher|BattlEye|BEService|^uu|uu_ovl|UUBooster|Netease|leigod|Leigod|QyClient|xunyou|v2ray|clash|sing-box|wireguard|tailscale|openvpn|netch|sstap'
$procs = Get-Process | Where-Object { $_.ProcessName -match $pat }
if (-not $procs) { Write-Output "(none found)" }
foreach ($p in $procs) {
  $pPath = if ($p.Path) { $p.Path } else { '(elevated, path hidden)' }
  Write-Output ("PROC {0} PID={1} PATH={2}" -f $p.ProcessName, $p.Id, $pPath)
}

Write-Output "=== [B] INSTALL DISCOVERY (verified only) ==="
$install = $null
$candidates = @('C:\SteamLibrary\steamapps\common\Escape from Tarkov')
# from uninstall registry
$keys = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')
Get-ItemProperty $keys | Where-Object { $_.DisplayName -match 'tarkov' } | ForEach-Object {
  if ($_.InstallLocation) { $candidates += $_.InstallLocation.TrimEnd('\') }
}
foreach ($c in $candidates) {
  if (Test-Path (Join-Path $c 'build\EscapeFromTarkov.exe')) { Write-Output ("VALID: " + $c); if (-not $install) { $install = $c } }
  elseif (Test-Path $c) { Write-Output ("EXISTS but no build\EscapeFromTarkov.exe: " + $c) }
  else { Write-Output ("STALE (dead link, ignore): " + $c) }
}
if (-not $install) { Write-Output "FATAL: no verified install found"; exit 1 }
Write-Output ("ACTIVE INSTALL: " + $install)

Write-Output "=== [C] SYSTEM PROXY + HOSTS ==="
$ie = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
Write-Output ("ProxyEnable={0} ProxyServer={1} AutoConfig={2}" -f $ie.ProxyEnable, $ie.ProxyServer, $ie.AutoConfigURL)
$hostLines = Get-Content "$env:SystemRoot\System32\drivers\etc\hosts" | Where-Object { $_ -match 'tarkov|battlestate|escapefrom' }
if ($hostLines) { $hostLines | ForEach-Object { Write-Output ("HOSTS: " + $_) } } else { Write-Output "(no tarkov entries in hosts)" }

Write-Output "=== [D] NETWORK ADAPTERS (up) ==="
Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
  Write-Output ("NIC {0} | {1}" -f $_.Name, $_.InterfaceDescription)
}

Write-Output "=== [E] NEWEST SESSION LOGS ==="
$logsRoot = Join-Path $install 'build\Logs'
$sess = Get-ChildItem $logsRoot -Directory | Sort-Object Name | Select-Object -Last 1
if (-not $sess) { Write-Output "FATAL: no session dirs under $logsRoot"; exit 1 }
Write-Output ("SESSION: " + $sess.FullName)
Get-ChildItem $sess.FullName -File | ForEach-Object {
  Write-Output ("FILE: {0}  {1}KB  (mod {2})" -f $_.Name, [math]::Round($_.Length/1KB,1), $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
}

foreach ($s in @(
  @{pat='*backend_000.log'; t=45},
  @{pat='*errors_000.log';  t=60},
  @{pat='*ping_000.log';    t=20},
  @{pat='*output_000.log';  t=60}
)) {
  $f = Get-ChildItem $sess.FullName -Filter $s.pat -File | Select-Object -First 1
  if ($f) {
    Write-Output ("########## {0} (last {1} lines) ##########" -f $f.Name, $s.t)
    Get-Content $f.FullName -Tail $s.t | ForEach-Object { Write-Output $_ }
    Write-Output ""
  }
}

Write-Output "=== [F] STATUS CODE COUNTS IN THIS SESSION ==="
$bl = Get-ChildItem $sess.FullName -Filter '*backend_000.log' -File | Select-Object -First 1
if ($bl) {
  $ok   = (Select-String -Path $bl.FullName -Pattern '<--- Response HTTPS' -SimpleMatch).Count
  $n403 = (Select-String -Path $bl.FullName -Pattern 'responseCode:403' -SimpleMatch).Count
  Write-Output ("backend: ok={0} 403={1}" -f $ok, $n403)
}

Write-Output "=== [G] RECENT CRASH DUMPS (7 days, by app) ==="
$cd = "$env:LOCALAPPDATA\CrashDumps"
if (Test-Path $cd) {
  $dumps = Get-ChildItem $cd -File | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) } | Sort-Object LastWriteTime -Descending
  if ($dumps) {
    $dumps | Select-Object -First 15 | ForEach-Object {
      Write-Output ("DUMP: {0}  {1}KB  {2}" -f $_.Name, [math]::Round($_.Length/1KB), $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))
    }
    $dumps | Group-Object { ($_.Name -split '\.')[0] } | Sort-Object Count -Descending | ForEach-Object {
      Write-Output ("SUMMARY: {0} x{1}" -f $_.Name, $_.Count)
    }
  } else { Write-Output "(none in 7 days)" }
} else { Write-Output "(no crashdumps dir)" }

Write-Output "=== DONE ==="
