<#
Host-side preflight for the local k3s lab (Windows PowerShell 5.1). Read-only.
Checks the laptop and the VirtualBox VMs, then runs k3s-preflight.sh on node1 over SSH.
Usage: .\scripts\k3s-preflight-host.ps1 [-NodeUser apantoja] [-SshPort 2221] [-MinFreeGB 3] [-SkipNode]
SSH asks for the node1 password once.
#>
param(
  [string]$NodeUser = 'apantoja',
  [int]$SshPort = 2221,
  [int]$MinFreeGB = 3,
  [switch]$SkipNode
)

$vb = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
$fail = 0
$warn = 0
function Ok($m)   { Write-Host "PASS  $m" }
function Bad($m)  { Write-Host "FAIL  $m"; $script:fail++ }
function Note($m) { Write-Host "WARN  $m"; $script:warn++ }

# 1. VirtualBox is installed.
if (-not (Test-Path $vb)) {
  Bad 'VBoxManage not found'
  exit 1
}

# 2. Both VMs are running.
$running = & $vb list runningvms | ForEach-Object { ($_ -split '"')[1] }
foreach ($n in 'node1', 'node2') {
  if ($running -contains $n) { Ok "$n is running" } else { Bad "$n is not running" }
}

# 3. No VirtualBox windows open (they use host memory; headless is lighter).
$gui = Get-Process -Name 'VirtualBox', 'VirtualBoxVM' -ErrorAction SilentlyContinue
if ($gui) { Note 'VirtualBox Manager or a VM window is open; close it and keep the VMs headless' } else { Ok 'No VirtualBox windows open' }

# 4. Free memory on the host.
$os = Get-CimInstance Win32_OperatingSystem
$freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
if ($freeGB -ge $MinFreeGB) { Ok "Host free memory: $freeGB GB" } else { Bad "Host free memory: $freeGB GB (minimum $MinFreeGB); close heavy applications" }
$top = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 3 | ForEach-Object { "$($_.ProcessName) $([math]::Round($_.WorkingSet64 / 1MB)) MB" }
Write-Host ("      largest memory users: " + ($top -join '; '))

# 5. Free disk on C:.
$disk = Get-PSDrive -Name C
$diskGB = [math]::Round($disk.Free / 1GB, 1)
if ($diskGB -ge 10) { Ok "Host disk free on C: $diskGB GB" } else { Bad "Host disk free on C: $diskGB GB (minimum 10)" }

# 6. Node-side checks over SSH.
$nodeFailed = $false
if (-not $SkipNode -and $running -contains 'node1') {
  Write-Host ''
  Write-Host '--- node1 ---'
  $script = (Get-Content -Raw (Join-Path $PSScriptRoot 'k3s-preflight.sh')) -replace "`r", ''
  $script | ssh -p $SshPort "$NodeUser@127.0.0.1" 'bash -s'
  if ($LASTEXITCODE -ne 0) { $nodeFailed = $true }
}

Write-Host ''
if ($fail -eq 0 -and -not $nodeFailed) {
  Write-Host "OVERALL VERDICT: READY ($warn host warnings)"
  exit 0
} else {
  Write-Host "OVERALL VERDICT: NOT READY ($fail host failures; node checks failed: $nodeFailed)"
  exit 1
}
