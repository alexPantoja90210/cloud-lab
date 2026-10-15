# Runbook: networking session, Azure (CLOUD-27)

The Terraform twin of the console build of 15 Oct 2026. Azure only for now; the AWS build is a separate
section to be added once it has been built by hand. One session, about 1 to 2 hours. Layer 1 is destroyed
at the end. The Terraform in `azure/layer1/networking.tf` was written and parsed on 15 Oct but **not yet
planned or applied**: the first plan is the first real test of it. Read each plan before applying it.

## Cost (estimate, stated before running)

- Private endpoint 0.01 USD an hour. VM `Standard_B1s` 0.0120 USD an hour plus a 30 GB Standard SSD at
  about 0.0033 USD an hour. Private DNS zone about 0.50 USD a month, prorated. Two hours is about
  0.05 USD. Credits cover it. Left running for a month the endpoint and the VM alone would be about
  19 USD, so teardown is not optional.
- Virtual network, subnets, security groups and the storage account at rest are free.
- Write the end time before applying. The real figure is read the next day in Cost analysis.

## What the root contains

`azure/layer1` also holds the storage, identity-probe and compute resources of earlier sessions, so this
session plans with `-target`, as the compute session did.

```powershell
$t = @(
  "-target=azurerm_linux_virtual_machine.net_client",
  "-target=azurerm_private_endpoint.net",
  "-target=azurerm_subnet_network_security_group_association.net_db",
  "-target=azurerm_network_security_rule.net_web_https",
  "-target=azurerm_network_security_rule.net_db_sql_from_web",
  "-target=azurerm_network_security_rule.net_db_deny_internet",
  "-target=azurerm_network_security_rule.net_db_deny_web_other"
)
```

## Before applying

```powershell
terraform fmt -check -recursive azure/layer1
terraform "-chdir=azure/layer1" init "-backend-config=backend.local.hcl"
terraform "-chdir=azure/layer1" validate
```

## Phase A: plan (free), read it, apply

```powershell
terraform "-chdir=azure/layer1" plan @t "-out=net.tfplan"
```

Expected from reading the code: `19 to add, 0 to change, 0 to destroy` (suffix, key, network, two
subnets, two security groups, two associations, four rules, storage account, DNS zone, DNS link,
endpoint, interface, VM). If the count differs, stop and read it. Check the subnet `snet-db` shows
`private_endpoint_network_policies = "Disabled"`.

```powershell
terraform "-chdir=azure/layer1" apply net.tfplan
```

Read the client from inside, with no login. The script prints only an address and `open` or `blocked`:

```powershell
$vm   = terraform "-chdir=azure/layer1" output -raw net_vm_name
$acct = terraform "-chdir=azure/layer1" output -raw net_storage_account
$ip   = terraform "-chdir=azure/layer1" output -raw net_endpoint_ip
$script = "echo dns:; getent hosts $acct.blob.core.windows.net | awk '{print `$1}'; echo 443:; timeout 5 bash -c '</dev/tcp/$ip/443' && echo open || echo blocked"
az vm run-command invoke --resource-group rg-cloud-lab --name $vm --command-id RunShellScript --scripts $script --query "value[0].message" --output tsv
```

Expected in phase A: the name resolves to the private address, and 443 is `open` even though rule 300
denies the web subnet, because the db subnet ignores its NSG for endpoint traffic.

## Phase B: make the NSG apply

```powershell
terraform "-chdir=azure/layer1" plan @t "-var=net_pe_nsg_enforced=true" "-out=net-b.tfplan"
terraform "-chdir=azure/layer1" apply net-b.tfplan
```

Expected plan: `0 to add, 1 to change, 0 to destroy` (the subnet). Run the same `az vm run-command invoke`;
expected `blocked`, decided by rule 300.

## Phase C: the allowed door

```powershell
terraform "-chdir=azure/layer1" plan @t "-var=net_pe_nsg_enforced=true" "-var=net_allow_web_to_pe=true" "-out=net-c.tfplan"
```

Add `"-target=azurerm_network_security_rule.net_db_allow_web_to_pe"` to `$t` first. Expected: `1 to add`.
After apply the same read gives `open`, decided by rule 150 (lower number wins over 300).

## Phase D: close the public door

```powershell
terraform "-chdir=azure/layer1" plan @t "-var=net_pe_nsg_enforced=true" "-var=net_allow_web_to_pe=true" "-var=net_public_access=false" "-out=net-d.tfplan"
```

Expected: `0 to add, 1 to change` (the account). From the laptop:

```powershell
curl.exe -s -D - -o NUL "https://$acct.blob.core.windows.net/?comp=list" | Select-String "HTTP/"
```

Expected `403 This request is not authorized to perform this operation`.

## Teardown and verification

```powershell
& $bash scripts/teardown.sh azure
az resource list --resource-group rg-cloud-lab --query "[].type" --output tsv
```

Expected: nothing in the layer 1 group. The network watchers and the layer 0 resources stay. Read every
file in `evidence/` before committing.

## After

- Next day: read the cost in Cost analysis for `domain = networking`, record it with its date in
  `docs/credit-log.md`, and compare it with the CLI report.
- In the note, list what the console build did differently from Terraform (subnet-per-session group,
  portal defaults such as the disk type and the endpoint policy setting) and what each difference cost.
