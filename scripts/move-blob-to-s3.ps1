<#
.SYNOPSIS
  Move every blob of one Azure container to one S3 bucket (CLOUD-34).

.DESCRIPTION
  Dry run by default: lists what would move and how each blob maps (tier -> storage class,
  metadata keys, content type). Nothing is downloaded or uploaded.
  -Execute   downloads each blob, uploads it with put-object and checks that the local MD5 equals
             the ETag S3 returns (true for a single-part upload with SSE-S3).
  -Rollback  deletes from the bucket the keys that exist in the source container.
  The source container is never modified or deleted by this script.
  Archive-tier blobs are refused: they must be rehydrated first.
  Windows PowerShell 5.1 compatible. Prints no account, bucket or subscription identifiers.
#>
param(
  [Parameter(Mandatory = $true)][string]$Account,
  [Parameter(Mandatory = $true)][string]$Bucket,
  [string]$Container = "data",
  [string]$Region = "us-east-1",
  [switch]$Execute,
  [switch]$Rollback
)

$ErrorActionPreference = "Stop"
$stage = Join-Path $env:TEMP "move-stage"

function Get-ClassFor([string]$tier) {
  switch ($tier) {
    "Cool"    { return "STANDARD_IA" }
    "Cold"    { return "STANDARD_IA" }
    "Archive" { return $null }
    default   { return "STANDARD" }
  }
}

$names = @(az storage blob list --account-name $Account --container-name $Container --auth-mode login --query "[].name" -o tsv | Where-Object { $_ })
if ($LASTEXITCODE -ne 0) { throw "Could not list the source container." }
"Source objects: $($names.Count)"

if ($Rollback) {
  foreach ($n in $names) {
    aws s3api delete-object --bucket $Bucket --key $n --region $Region | Out-Null
    "deleted from destination: $n"
  }
  return
}

if ($Execute) { New-Item -ItemType Directory -Force $stage | Out-Null }

$rows = @()
foreach ($n in $names) {
  $b = az storage blob show --account-name $Account --container-name $Container --name $n --auth-mode login -o json | Out-String | ConvertFrom-Json
  $tier = $b.properties.blobTier
  $class = Get-ClassFor $tier
  if (-not $class) { throw "Blob '$n' is in the Archive tier. Rehydrate it first." }
  $ct = $b.properties.contentSettings.contentType
  $pairs = @()
  if ($b.metadata) { foreach ($p in $b.metadata.PSObject.Properties) { $pairs += ($p.Name + "=" + $p.Value) } }
  $meta = $pairs -join ","

  $row = [ordered]@{ Key = $n; Size = $b.properties.contentLength; Tier = $tier; Class = $class; Meta = $meta; Md5 = ""; Etag = ""; Match = "" }

  if ($Execute) {
    $file = Join-Path $stage $n
    az storage blob download --account-name $Account --container-name $Container --name $n --file $file --auth-mode login -o none
    if ($LASTEXITCODE -ne 0) { throw "Download failed for $n" }
    $md5 = (Get-FileHash -Algorithm MD5 $file).Hash.ToLower()
    $awsArgs = @("s3api", "put-object", "--bucket", $Bucket, "--key", $n, "--body", $file, "--content-type", $ct, "--storage-class", $class, "--region", $Region, "--query", "ETag", "--output", "text")
    if ($meta) { $awsArgs += @("--metadata", $meta) }
    $raw = & aws @awsArgs
    if ($LASTEXITCODE -ne 0) { throw "Upload failed for $n" }
    $etag = ([string]$raw).Trim().Trim('"')
    $row.Md5 = $md5
    $row.Etag = $etag
    $row.Match = if ($md5 -eq $etag) { "OK" } else { "MISMATCH" }
  }
  $rows += [pscustomobject]$row
}

if ($Execute) {
  $dst = @(aws s3api list-objects-v2 --bucket $Bucket --region $Region --query "Contents[].Key" --output text) -split "\s+" | Where-Object { $_ }
  $missing = @($names | Where-Object { $dst -notcontains $_ })
  $bad = @($rows | Where-Object { $_.Match -ne "OK" })
  $rows | Format-Table Key, Size, Tier, Class, Meta, Match -AutoSize
  "Missing in destination: $($missing.Count). Checksum mismatches: $($bad.Count)."
  Remove-Item -Recurse -Force $stage
  if ($missing.Count -gt 0 -or $bad.Count -gt 0) { throw "VALIDATION FAILED" }
  "VALIDATION OK"
} else {
  $rows | Format-Table Key, Size, Tier, Class, Meta -AutoSize
  "Dry run only. Nothing was copied. Add -Execute to copy."
}
