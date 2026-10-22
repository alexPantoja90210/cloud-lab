# Runbook: networking session, Azure (CLOUD-27)

The Terraform twin of the console build of 15 Oct 2026. Azure only for now; the AWS build is a separate
section to be added once it has been built by hand. One session, about 1 to 2 hours. Layer 1 is destroyed
at the end. The Terraform in `azure/layer1/networking.tf` was written and parsed on 15 Oct and applied and destroyed
on 16 Oct (19 resources applied in four phases, 20 destroyed; see `docs/credit-log.md`). This paragraph
said "not yet planned" until 22 Oct and was out of date. Read each plan before applying it.

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
  "-target=azurerm_network_security_rule.net_db_deny_web_other",
  "-target=azurerm_private_dns_zone_virtual_network_link.net_blob"
)
```

The DNS link needs its own `-target`: nothing in the list depends on it, so the first plan (16 Oct) came
out at 18 instead of 19 and would have left the name resolving to the public address.

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

## AWS twin, 22 Oct 2026 (`aws/layer1/networking.tf`)

Built and destroyed in one session of about 15 minutes. Lambda client in `lambda/net_client.py`.
The failure is a switch: `deny_private_subnet = true` attaches a custom network ACL with no rules.

### How it was scoped

`aws/layer1` holds every AWS exercise (storage, compute, rehost, identity probe) and layer 1 is empty
between sessions, so a plain `plan` wanted all of them: **54 to add** (networking 25, the rest 30, minus one
resource with count 0). Applying that would have created a CloudFront distribution, a public API and the
rehost. The session used the same `-target` approach as the Azure twin:

```powershell
$t = @(
  "-target=aws_lambda_function.net_client",
  "-target=aws_iam_role_policy.net_client_s3",
  "-target=aws_route_table_association.public",
  "-target=aws_route_table_association.private",
  "-target=aws_vpc_security_group_ingress_rule.web_https",
  "-target=aws_vpc_security_group_ingress_rule.db_from_web",
  "-target=aws_vpc_security_group_egress_rule.client_all",
  "-target=aws_s3_bucket_public_access_block.net",
  "-target=aws_network_acl.private_deny"
)
terraform "-chdir=aws/layer1" plan @t -out net.tfplan
```

The Lambda target pulls its dependencies (VPC, subnets, bucket, endpoint, role, log group). The other targets
cover what nothing in the Lambda chain depends on. Result: **24 to add** (the ACL has count 0 by default).
Destroy needs no targets: only what is in the state is destroyed.

### Results

| Step | Result | Time |
|---|---|---|
| Plan, whole layer | 54 to add (not applied) | n/a |
| Plan, targeted | 24 to add | n/a |
| Apply | 24 added | not captured |
| Invoke, path open | `{"result": "ok", "key_count": 0}`, HTTP 200 | 4.9 s including cold start |
| Switch on: plan and apply | 1 to add (the ACL) | n/a |
| Invoke, ACL denies | HTTP 200 with FunctionError `Unhandled`: `Task timed out after 15.00 seconds`, no network error message | 16.3 s |
| Destroy | 25 destroyed | 292 s |

The same call that returned `ok` returned a bare timeout once the empty ACL was attached, with route,
endpoint, security group and code unchanged. This reproduces the console finding of 15 Oct.

### Teardown check

- Direct EC2 reads (subnets, VPC endpoints, security groups, security group rules, VPCs by tag): all 0.
- The tagging API (`lab=cloud-lab`, `layer=1`) still listed 5 EC2 entries right after destroy: one subnet,
  three security group rules and the S3 endpoint. They are parts of the network that was just destroyed and
  EC2 reports none, so they are most likely stale index entries. To re-read the tagging API later; not yet done.

### What went wrong

- `validate` rejected the security group names: AWS reserves the `sg-` prefix. Fixed with `net-web-tf`,
  `net-db-tf`, `net-client-tf`; the `Name` tag keeps the `sg-*-tf` form. My error, not known in advance.
- My expected plan size was for networking alone; the real plan covered the whole layer (54).
- My first count of tagged resources printed `1` because the CLI output came back as one line; the real
  number was 5. Count with an explicit split, not `.Count` on text.

### Cost

Nothing here bills by the hour (no NAT gateway). The Lambda ran for about 5 s and 15 s. Expected cost is a
fraction of a cent; the real figure is still to be read in Cost Explorer (filter `domain = networking`) and by CLI.

