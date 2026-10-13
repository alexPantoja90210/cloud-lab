# Runbook: compute session (CLOUD-28)

One session, about 3 to 4 hours, both clouds. Layer 1 is destroyed at the end. This is the Terraform
twin of the console session of 12 Oct 2026 (`docs/study/compute-azure-vs-aws.md`). The Terraform
below was written and parsed on 13 Oct but **not yet planned or applied**: the first plan is the
first real test of it. Read each plan before applying it.

## Cost (estimate, stated before running)

- Azure: one `Standard_B1s` at 0.0120 USD an hour (price shown in the wizard) plus a 30 GB Standard
  SSD at about 0.0033 USD an hour. Three hours is about 0.05 USD. Credits cover it. Left running for a
  month it would be about 11 USD, so teardown is not optional.
- AWS: Lambda, API Gateway and a log group at a few requests cost a fraction of a cent. Nothing bills
  at rest.
- The real figure is read the next day: Cost Management by meter on Azure, Cost Explorer by tag on AWS.
  Record it with its read date.

## What the root contains

`azure/layer1` and `aws/layer1` also hold the storage and identity-probe resources of earlier sessions.
A plain `terraform apply` would create those too, and some of them cost money (the probe runs a
container). This session therefore plans with `-target`, which Terraform warns about on purpose: it is
the right tool here and the wrong tool for everyday use. A `enable_<domain>` switch per domain would
remove the need for it and is still to be decided.

## Before applying

1. Same terminal window for the whole session: `AWS_PROFILE` and `ARM_SUBSCRIPTION_ID` set, `az login`
   valid. Env vars are lost when the window closes.
2. Both roots gained a provider (`tls` on Azure, `archive` on AWS), so `init` rewrites
   `.terraform.lock.hcl`. Commit those two lock files.
3. Check the format and the syntax, which costs nothing:

```powershell
terraform fmt -check -recursive azure/layer1 aws/layer1
terraform "-chdir=azure/layer1" init "-backend-config=backend.local.hcl"
terraform "-chdir=azure/layer1" validate
terraform "-chdir=aws/layer1" init "-backend-config=backend.local.hcl"
terraform "-chdir=aws/layer1" validate
```

If `fmt -check` lists files, run `terraform fmt -recursive azure/layer1 aws/layer1` and read the diff:
it must only move whitespace.

## 1. Plan (free) and read it

```powershell
terraform "-chdir=azure/layer1" plan "-target=azurerm_linux_virtual_machine.compute" "-out=compute.tfplan"
terraform "-chdir=aws/layer1" plan "-target=aws_apigatewayv2_route.hello" "-target=aws_apigatewayv2_stage.hello" "-target=aws_lambda_permission.hello_api" "-out=compute.tfplan"
```

Expected from reading the code: Azure `7 to add, 0 to change, 0 to destroy` (key, network, subnet,
security group, interface, association, VM). AWS `9 to add, 0 to change, 0 to destroy` (role,
policy attachment, log group, function, API, integration, route, stage, permission). If a count differs,
stop and read it. In the Azure plan check the VM size reads `Standard_B1s`, the zone `1`, and the
location `denmarkeast`.

## 2. Azure: apply, then power states

Note the UTC time each step starts and ends. The clock is the data.

```powershell
terraform "-chdir=azure/layer1" apply compute.tfplan
$vm = terraform "-chdir=azure/layer1" output -raw compute_vm_name
az vm show --resource-group rg-cloud-lab --name $vm --show-details --query powerState --output tsv
```

Expected: `VM running`. Then check that the OS disk carries the tags (the open question in
`azure/layer1/compute.tf`):

```powershell
az disk list --resource-group rg-cloud-lab --query "[].{type:type,domain:tags.domain,layer:tags.layer}" --output tsv
```

If `domain` and `layer` come back empty, the disk cost will fall in the untagged group: record it in the
note, and decide whether to fix it with a separate managed disk.

Hold each state about an hour, and set a phone alarm for each change:

```powershell
az vm stop --resource-group rg-cloud-lab --name $vm
az vm show --resource-group rg-cloud-lab --name $vm --show-details --query powerState --output tsv
az vm deallocate --resource-group rg-cloud-lab --name $vm
az vm show --resource-group rg-cloud-lab --name $vm --show-details --query powerState --output tsv
```

Expected: `VM stopped` (still billed), then `VM deallocated`. Read the exact times afterwards from the
activity log:

```powershell
az monitor activity-log list --resource-group rg-cloud-lab --offset 1d --max-events 200 --query "[].{op:operationName.localizedValue,t:eventTimestamp,s:status.value}" --output tsv
```

Expected next day: Running plus Stopped hours billed in the `B1s` meter, Deallocated not. Do not
create a Bastion or a public IP to look inside the VM.

## 3. AWS: apply, then the calls

```powershell
terraform "-chdir=aws/layer1" apply compute.tfplan
$env:PROBE_URL = terraform "-chdir=aws/layer1" output -raw compute_invoke_url
1..10 | ForEach-Object { curl.exe -s -o NUL -w "%{http_code}`n" $env:PROBE_URL }
```

Expected: ten `200`. The stage is throttled at 5 requests a second, so a faster loop would see `429`
(that is the throttle working, not an error). Then the tags on the API, which the console could not
set, and the log group retention:

```powershell
$apiId = aws apigatewayv2 get-apis --region us-east-1 --query "Items[?Name=='cloud-lab-hello-tf-API'].ApiId" --output text
aws apigatewayv2 get-tags --region us-east-1 --resource-arn "arn:aws:apigateway:us-east-1::/apis/$apiId" --output json
aws logs describe-log-groups --region us-east-1 --log-group-name-prefix /aws/lambda/cloud-lab-hello-tf --query "logGroups[].retentionInDays" --output json
```

Expected: the three tags, and `[7]`.

## 4. Teardown and verification

```powershell
& $bash scripts/teardown.sh aws
& $bash scripts/teardown.sh azure
```

Verify in the console or with these, not in the destroy output. All must come back empty:

```powershell
az resource list --resource-group rg-cloud-lab --query "[].type" --output tsv
aws resourcegroupstaggingapi get-resources --region us-east-1 --tag-filters Key=lab,Values=cloud-lab Key=layer,Values=1 --query "length(ResourceTagMappingList)" --output text
aws logs describe-log-groups --region us-east-1 --log-group-name-prefix /aws/lambda/cloud-lab-hello --query "logGroups[].logGroupName" --output json
aws iam list-roles --query "Roles[?starts_with(RoleName,'cloud-lab-hello')].RoleName" --output json
```

Expected: nothing, `0`, `[]`, `[]`. The log group and the role are the two things the console build left
behind; here Terraform removes them. Then `Remove-Item Env:PROBE_URL`.

## 5. After

- Read every file in `evidence/` before committing.
- Next day: read the cost by meter on Azure and by tag `domain=compute` on AWS, record it with its date
  in `docs/credit-log.md`, and update `docs/study/compute-azure-vs-aws.md`.
- In the note, list what the console build did differently from Terraform (log group retention, API tags,
  OS disk tags, the open route and its throttle) and what each difference cost.
