# Runbook: DR recovery drill, Azure (CLOUD-35)

Status: **draft, not run.** `terraform fmt` and `validate` passed on 17 Oct 2026 (about 17:38 local); the
file has not been planned or applied yet, so the first plan with `dr_restore=true` is its first real test. Targets are in `docs/study/dr-recovery-azure.md` (RPO 1 hour, RTO 1 hour). The plan
is `docs/plans/migration-dr-rehost-plan.md`. About 2 to 3 hours. Azure only for the disk; the AWS redeploy
time is measured at the end.

## Cost (estimate, stated before running)

About 0.05 USD: a `Standard_B1s` at 0.012 USD an hour for the hours it runs (one VM at a time, never two),
two 30 GB Standard SSD disks at about 0.0033 USD an hour each while they exist, and an incremental
snapshot for hours. Stop threshold from the plan: 0.25 USD for the day, or the end time written at the start.
The end time is written here before applying: `____`.

## 0. Before applying (free)

```powershell
terraform fmt -check -recursive azure/layer1
terraform "-chdir=azure/layer1" validate
```

If `validate` fails on `dr.tf`, stop and paste the error. (It passed on 17 Oct; repeat it anyway.)

## 1. Build the VM and the snapshot (expected 8 to add)

```powershell
terraform "-chdir=azure/layer1" plan "-target=azurerm_linux_virtual_machine.compute" "-target=azurerm_snapshot.compute" "-out=dr-build.tfplan"
terraform "-chdir=azure/layer1" apply dr-build.tfplan
```

Compare the plan count with 8 before applying. Write the UTC time when the VM is `running`.

## 2. The disaster, by hand in the portal

Delete the VM and its OS disk. Do not delete the network interface or the snapshot. Write **T0**, the UTC
time of the delete, and check the snapshot is still listed.

## 3. Recovery by hand (portal), timed

Create a disk from the snapshot (name it `disk-manual`), then create a VM from that disk. In the wizard:
size B1s, zone 1, **public IP: none**, tick *delete NIC when the VM is deleted*, no Bastion. Write the UTC
time of every step and **T1**, when the VM shows `Running`. Manual recovery time is T1 minus T0.

Then delete that VM and its disk `disk-manual`, and confirm no VM exists. Write **T2**.

## 4. Recovery by Terraform and the CLI, timed

```powershell
terraform "-chdir=azure/layer1" plan "-var=dr_restore=true" "-target=azurerm_managed_disk.restored" "-out=dr-restore.tfplan"
terraform "-chdir=azure/layer1" apply dr-restore.tfplan
```

Expected: `1 to add`, and no VM in the plan. Then the VM from the restored disk (reusing the NIC that
still exists; this prints only the VM name and the state):

```powershell
$nic = az network nic show --resource-group rg-cloud-lab --name nic-cloud-lab-compute --query id -o tsv
az vm create --resource-group rg-cloud-lab --name vm-cloud-lab-restored --attach-os-disk disk-cloud-lab-restored --os-type linux --nics $nic --size Standard_B1s --zone 1 --tags lab=cloud-lab layer=1 domain=compute --query "{name:name,state:provisioningState}" -o tsv
```

Write **T3**, when the CLI returns and the VM is `Running`. Terraform and CLI recovery time is T3 minus T2.

## 5. Compare

Table of step against minutes for both paths; where the time went; what would shorten it. Compare with
the RTO hypothesis of 60 minutes.

## 6. AWS redeploy time

Destroy and rebuild the CLOUD-28 Lambda, HTTP API and log group from Terraform and time the apply: that is
the AWS RTO. Exact targets to be written when this step is reached.

## 7. Teardown and verification

The VM created with the CLI is not in the Terraform state, and it holds the restored disk and the NIC, so
delete it first:

```powershell
az vm delete --resource-group rg-cloud-lab --name vm-cloud-lab-restored --yes
& $bash scripts/teardown.sh azure
az resource list --resource-group rg-cloud-lab --query "[].type" --output tsv
az snapshot list --resource-group rg-cloud-lab --query "[].name" --output tsv
```

Expected: both lists empty. Run `powershell -File scripts/inventory.ps1`. Read every file in `evidence/`
before committing.

## 8. After

Next day, read cost by meter in the portal (tag `domain=compute`) and from the CLI; record both with the
date in `docs/credit-log.md`. Fill in the results of `docs/study/dr-recovery-azure.md` and update the
plan with what it got wrong.
