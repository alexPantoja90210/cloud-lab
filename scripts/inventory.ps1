# Read-only inventory of what exists in both clouds and what bills while idle.
# Prints types, counts and tags only: no names, IDs or addresses.
# Usage: pwsh scripts/inventory.ps1   (or: powershell -File scripts/inventory.ps1)
# Needs az login and AWS_PROFILE in the same terminal. Costs nothing: it only lists.
param([string]$Region = "us-east-1")

# Types that bill every hour they exist, or that bill while stopped and idle.
$hourly = @(
  'Microsoft.Network/privateEndpoints', 'Microsoft.Compute/virtualMachines',
  'Microsoft.Network/publicIPAddresses', 'Microsoft.Network/bastionHosts',
  'Microsoft.Network/natGateways', 'Microsoft.Network/loadBalancers',
  'Microsoft.Network/applicationGateways', 'Microsoft.Network/azureFirewalls',
  'Microsoft.Network/virtualNetworkGateways', 'Microsoft.ContainerInstance/containerGroups'
)
$atRest = @('Microsoft.Compute/disks', 'Microsoft.Compute/snapshots', 'Microsoft.Storage/storageAccounts', 'Microsoft.Network/privateDnsZones')

Write-Host "== AZURE: everything in the subscription, by type / layer / domain =="
$rows = az resource list --query "[].{t:type,l:tags.layer,d:tags.domain}" --output json | ConvertFrom-Json
if (-not $rows) { Write-Host "(nothing)" } else {
  $rows | Group-Object t, l, d | Sort-Object Name | ForEach-Object {
    $r = $_.Group[0]
    $flag = if ($hourly -contains $r.t) { "BILLS BY THE HOUR" } elseif ($atRest -contains $r.t) { "bills at rest" } else { "free at rest" }
    "{0,3} x {1,-52} layer={2,-2} domain={3,-11} {4}" -f $_.Count, $r.t, $r.l, $r.d, $flag
  }
  $untagged = @($rows | Where-Object { -not $_.l }).Count
  Write-Host "Untagged (no layer tag): $untagged"
}

Write-Host ""
Write-Host "== AWS ($Region): tagged resources by service / type, and the hourly-billing checks =="
$arns = aws resourcegroupstaggingapi get-resources --region $Region --query "ResourceTagMappingList[].ResourceARN" --output json | ConvertFrom-Json
if (-not $arns) { Write-Host "(no tagged resources)" } else {
  $arns | ForEach-Object {
    $p = $_ -split ':'
    [pscustomobject]@{ svc = $p[2]; kind = (($p[5..($p.Length - 1)] -join ':') -split '[/:]')[0] }
  } | Group-Object svc, kind | Sort-Object Name | ForEach-Object { "{0,3} x {1} / {2}" -f $_.Count, $_.Group[0].svc, $_.Group[0].kind }
}
Write-Host "NAT gateways not deleted : $(aws ec2 describe-nat-gateways --region $Region --query "length(NatGateways[?State!='deleted'])" --output text)"
Write-Host "Elastic IPs              : $(aws ec2 describe-addresses --region $Region --query "length(Addresses)" --output text)"
Write-Host "Interface VPC endpoints  : $(aws ec2 describe-vpc-endpoints --region $Region --query "length(VpcEndpoints[?VpcEndpointType=='Interface'])" --output text)"
Write-Host "EC2 instances running    : $(aws ec2 describe-instances --region $Region --filters Name=instance-state-name,Values=running --query "length(Reservations[].Instances[])" --output text)"
Write-Host ""
Write-Host "Limits: AWS shows only tagged resources in one region. An untagged resource is invisible here;"
Write-Host "the four checks above cover the things that bill by the hour. Cost by tag is read in Cost Explorer."
