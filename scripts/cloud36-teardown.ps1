<#
.SYNOPSIS
  Tear down the hand-built CLOUD-36 layer (Azure PyME model). Dry run by default.

.DESCRIPTION
  Finds, by tag and exact name (no variables from an earlier session needed):
    - storage accounts in the resource group that carry the tag `department` and start with `stlab`
    - Entra groups grp-finance, grp-hr, grp-operations, grp-engineering
    - app registrations (and their service principals) sp-lab-alice and sp-lab-bob
  Without -Execute it only prints counts. With -Execute it deletes them, removes the local login folders of the
  test identities (they hold token caches) and prints counts again.
  Prints no names, IDs or secrets. Windows PowerShell 5.1 compatible (no JMESPath parentheses).

.EXAMPLE
  .\scripts\cloud36-teardown.ps1            # dry run
  .\scripts\cloud36-teardown.ps1 -Execute   # delete
#>
param(
  [switch]$Execute,
  [string]$ResourceGroup = 'rg-cloud-lab'
)

$depts = 'finance', 'hr', 'operations', 'engineering'
$people = 'sp-lab-alice', 'sp-lab-bob'

function Get-Accounts {
  @(az storage account list -g $ResourceGroup --query "[?tags.department].name" -o tsv 2>$null | Where-Object { $_ -like 'stlab*' })
}
function Get-GroupIds {
  $ids = @()
  foreach ($d in $depts) { $ids += @(az ad group list --display-name "grp-$d" --query "[?displayName=='grp-$d'].id" -o tsv 2>$null | Where-Object { $_ }) }
  $ids
}
function Get-AppIds {
  $ids = @()
  foreach ($p in $people) { $ids += @(az ad app list --display-name $p --query "[?displayName=='$p'].appId" -o tsv 2>$null | Where-Object { $_ }) }
  $ids
}

$accts = Get-Accounts
$groups = Get-GroupIds
$apps = Get-AppIds
$mode = if ($Execute) { 'EXECUTE' } else { 'DRY RUN' }
Write-Host "[$mode] found: storage accounts $($accts.Count), groups $($groups.Count), app registrations $($apps.Count)"

if (-not $Execute) {
  Write-Host 'Nothing was deleted. Run again with -Execute to delete the items counted above.'
  exit 0
}

foreach ($a in $accts)  { az storage account delete -n $a -g $ResourceGroup --yes 2>$null | Out-Null }
foreach ($g in $groups) { az ad group delete --group $g 2>$null | Out-Null }
foreach ($i in $apps)   { az ad app delete --id $i 2>$null | Out-Null }
Remove-Item (Join-Path $env:TEMP 'azalice'), (Join-Path $env:TEMP 'azbob') -Recurse -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 5
$accts2 = Get-Accounts
$groups2 = Get-GroupIds
$apps2 = Get-AppIds
Write-Host "[AFTER] left: storage accounts $($accts2.Count), groups $($groups2.Count), app registrations $($apps2.Count)"
$types = @(az resource list -g $ResourceGroup --query "[].type" -o tsv 2>$null | Where-Object { $_ })
Write-Host "Resources of any kind left in the resource group: $($types.Count)"
if ($accts2.Count + $groups2.Count + $apps2.Count -eq 0) { Write-Host 'RESULT: clean' } else { Write-Host 'RESULT: something is left; run again' }
