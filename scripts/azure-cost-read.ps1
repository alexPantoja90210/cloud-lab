<#
.SYNOPSIS
  Read the Azure cost of the lab from the CLI (Cost Management query API), grouped by meter.

.DESCRIPTION
  One query per value of the tag `domain`. Prints cost (USD, gross, before credits) and usage quantity per meter.
  -All adds one more query with no tag filter, for meters that do not carry the lab tags (for example data transfer).
  Read-only and free. Prints no subscription id. Cost data lags up to a day; the API can answer 429 when called often.
  Windows PowerShell 5.1 compatible: the body goes through a temp file and the JSON is filtered in PowerShell, because
  JMESPath with parentheses breaks through az.cmd.

.EXAMPLE
  powershell -File scripts/azure-cost-read.ps1 -From 2026-10-14 -To 2026-10-19 -All
#>
param(
  [Parameter(Mandatory = $true)][string]$From,
  [Parameter(Mandatory = $true)][string]$To,
  [string[]]$Domains = @("compute", "storage", "rehost", "networking"),
  [switch]$All,
  [switch]$OnlyAll
)

$ErrorActionPreference = "Stop"
$sub = az account show --query id -o tsv
if (-not $sub) { throw "No Azure login." }
$url = "https://management.azure.com/subscriptions/$sub/providers/Microsoft.CostManagement/query?api-version=2023-11-01"

function Invoke-CostQuery([string]$label, $filter) {
  $ErrorActionPreference = "Continue"
  $dataset = [ordered]@{
    granularity = "None"
    aggregation = [ordered]@{
      totalCost = @{ name = "Cost"; function = "Sum" }
      qty       = @{ name = "UsageQuantity"; function = "Sum" }
    }
    grouping    = @(@{ type = "Dimension"; name = "Meter" })
  }
  if ($filter) { $dataset["filter"] = $filter }
  $body = [ordered]@{
    type       = "ActualCost"
    timeframe  = "Custom"
    timePeriod = @{ from = "${From}T00:00:00Z"; to = "${To}T23:59:59Z" }
    dataset    = $dataset
  }
  $file = Join-Path $env:TEMP "cost-body.json"
  ($body | ConvertTo-Json -Depth 8) | Set-Content -Encoding ascii $file
  $raw = ""
  for ($try = 1; $try -le 4; $try++) {
    $raw = az rest --method post --url $url --body "@$file" -o json 2>$null | Out-String
    if ($LASTEXITCODE -eq 0 -and $raw.Trim()) { break }
    Start-Sleep -Seconds (15 * $try)
  }
  Remove-Item $file -Force
  if ($LASTEXITCODE -ne 0 -or -not $raw.Trim()) { "=== $label ($From to $To)"; "    QUERY FAILED after 4 tries (rate limit?). This is not 'no data'."; return }
  $res = $raw | ConvertFrom-Json
  $cols = @($res.properties.columns | ForEach-Object { $_.name })
  $rows = @()
  foreach ($r in $res.properties.rows) {
    $o = [ordered]@{}
    for ($i = 0; $i -lt $cols.Count; $i++) { $o[$cols[$i]] = $r[$i] }
    $rows += [pscustomobject]$o
  }
  "=== $label ($From to $To)"
  if ($rows.Count -eq 0) { "    no rows"; return }
  $rows | Sort-Object Cost -Descending | Format-Table @{n = "Meter"; e = { $_.Meter } }, @{n = "Cost USD"; e = { [math]::Round($_.Cost, 5) } }, @{n = "Quantity"; e = { [math]::Round($_.UsageQuantity, 5) } } -AutoSize
  "    total: " + [math]::Round((($rows | Measure-Object Cost -Sum).Sum), 5) + " USD"
}

if (-not $OnlyAll) { foreach ($d in $Domains) {
  Invoke-CostQuery "tag domain=$d" @{ Tags = @{ name = "domain"; operator = "In"; values = @($d) } }
  Start-Sleep -Seconds 2
} }
if ($All -or $OnlyAll) { Invoke-CostQuery "all meters, no tag filter" $null }
