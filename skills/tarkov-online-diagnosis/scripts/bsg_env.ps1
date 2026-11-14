# bsg_env.ps1 - launcher dirs, caches, GPU/OS info (read-only, ASCII output)
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Output "=== [A] LAUNCHER DIR CONTENTS (SteamLibrary bundled) ==="
$ld = 'C:\SteamLibrary\steamapps\common\Escape from Tarkov\launcher'
if (Test-Path $ld) {
  Get-ChildItem $ld -Force | ForEach-Object {
    $kind = if ($_.PSIsContainer) { 'DIR ' } else { 'FILE' }
    $len = if ($_.PSIsContainer) { '' } else { ' ' + [math]::Round($_.Length/1KB,1) + 'KB' }
    Write-Output ("  {0} {1}{2}  (mod {3})" -f $kind, $_.Name, $len, $_.LastWriteTime.ToString('yyyy-MM-dd'))
  }
} else { Write-Output "(missing): $ld" }

Write-Output "=== [B] LAUNCHER DATA DIR CANDIDATES ==="
Write-Output "NOTE: Battlestate Games data lives in BOTH AppData roots - probe LOCALAPPDATA first (Logs/CefCache there)."
$cands = @(
  "$env:APPDATA\Battlestate Games\BsgLauncher",
  "$env:LOCALAPPDATA\Battlestate Games\BsgLauncher",
  "$env:LOCALAPPDATA\BsgLauncher"
)
foreach ($c in $cands) {
  if (Test-Path $c) {
    Write-Output ("EXISTS: " + $c)
    Get-ChildItem $c -Force | Select-Object -First 15 | ForEach-Object {
      $kind = if ($_.PSIsContainer) { 'DIR ' } else { 'FILE' }
      $len = if ($_.PSIsContainer) { '' } else { ' ' + [math]::Round($_.Length/1KB,1) + 'KB' }
      Write-Output ("    {0} {1}{2}  (mod {3})" -f $kind, $_.Name, $len, $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))
    }
  } else { Write-Output ("(no): " + $c) }
}

Write-Output "=== [C] STEAM APP MANIFESTS ==="
Get-ChildItem 'C:\SteamLibrary\steamapps' -Filter 'appmanifest_*.acf' | ForEach-Object {
  $head = Get-Content $_.FullName -TotalCount 8
  $name = ($head | Where-Object { $_ -match '"name"' }) -join ''
  $bid  = ($head | Where-Object { $_ -match '"buildid"' }) -join ''
  Write-Output ("ACF: {0}  {1} {2}" -f $_.Name, $name.Trim(), $bid.Trim())
}

Write-Output "=== [D] GPU + OS + RAM ==="
Get-CimInstance Win32_VideoController | ForEach-Object {
  Write-Output ("GPU: {0} | driver {1} ({2})" -f $_.Name, $_.DriverVersion, $_.DriverDate)
}
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
Write-Output ("OS: {0} build {1}" -f $os.Caption, $os.BuildNumber)
Write-Output ("CPU: {0}" -f $cpu.Name.Trim())
Write-Output ("RAM GB: " + [math]::Round($cs.TotalPhysicalMemory/1GB,1))

Write-Output "=== DONE ==="
