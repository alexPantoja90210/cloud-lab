<#
.SYNOPSIS
  Remove the local files and VirtualBox objects that the migration and rehost drills create.

.DESCRIPTION
  Dry run by default: lists what exists and its size. -Execute deletes.
  Default scope (safe after every session): the CLOUD-34 test data and the 64 MiB export sample.
  -IncludeRehost (use it when CLOUD-38 is finished): also removes the VM clone rehost-src and its
  disk, the exported 20 GiB VHD and its dynamic copy (CLOUD-38), the lab SSH key id_rehost, its known_hosts entry and the labnet
  port-forward rule named rehost.
  Never touches node1, node2 or rhel10-template. Windows PowerShell 5.1 compatible.
#>
param([switch]$Execute, [switch]$IncludeRehost)

$ErrorActionPreference = "Stop"
$vbm = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$export = Join-Path $env:USERPROFILE "rehost-export"

$paths = @(
  (Join-Path $env:TEMP "move-src"),
  (Join-Path $env:TEMP "move-stage"),
  (Join-Path $env:USERPROFILE "Downloads\move-manual"),
  (Join-Path $export "sample-1GiB.bin")
)
if ($IncludeRehost) {
  $paths += @($export, (Join-Path $env:USERPROFILE ".ssh\id_rehost"), (Join-Path $env:USERPROFILE ".ssh\id_rehost.pub"))
}

function Get-SizeMB([string]$p) {
  if (Test-Path $p -PathType Container) {
    $s = (Get-ChildItem $p -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
  } else {
    $s = (Get-Item $p).Length
  }
  [math]::Round($s / 1MB, 1)
}

"Mode: " + $(if ($Execute) { "EXECUTE" } else { "dry run" })

if ($IncludeRehost) {
  $vms = & $vbm list vms
  if ($vms -match '"rehost-src"') {
    "VirtualBox VM: rehost-src (with its own disk)"
    if ($Execute) {
      $state = (& $vbm showvminfo rehost-src --machinereadable | Select-String "^VMState=").ToString()
      if ($state -notmatch "poweroff") { throw "rehost-src is not powered off. Power it off first." }
      & $vbm unregistervm rehost-src --delete
    }
  } else { "VirtualBox VM: rehost-src absent" }
  "VirtualBox port-forward rule: rehost (labnet)"
  "VirtualBox media entries: every .vhd in rehost-export (closed before the files are deleted)"
  if ($Execute) {
    & $vbm natnetwork modify --netname labnet --port-forward-4 delete rehost
    # Every VHD that VBoxManage opened stays in the VirtualBox media registry: close each one first.
    foreach ($f in (Get-ChildItem $export -Filter "*.vhd" -ErrorAction SilentlyContinue)) {
      try { & $vbm closemedium disk $f.FullName 2>&1 | Out-Null } catch { "closemedium skipped: " + $f.Name }
    }
    ssh-keygen -R "[127.0.0.1]:2204" | Out-Null
  }
}

foreach ($p in $paths) {
  if (Test-Path $p) {
    "{0,10} MB  {1}" -f (Get-SizeMB $p), $p
    if ($Execute) { Remove-Item -Recurse -Force $p }
  } else {
    "    absent  $p"
  }
}

if (-not $Execute) { "Dry run only. Add -Execute to delete." } else { "Done." }
