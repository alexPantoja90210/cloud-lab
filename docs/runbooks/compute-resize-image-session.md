# Runbook: compute resize and image session (CLOUD-28, part 2)

Azure only. The first session (`compute-session.md`, 14 Oct 2026) covered build, power states and
destroy. This one covers the two remaining parts of the criterion: resize and image. About one hour.
AWS has no VM in this lab (Lambda has no machine to resize or image), so it is not part of this session.

## Cost (estimate, stated before running)

Azure only: about 0.15 hours of `Standard_B1s` (0.012 USD an hour) and the same of `Standard_B2ats_v2`
(list price to be read from the meter afterwards), the 30 GB disk at about 0.0033 USD an hour, and an
incremental snapshot of a mostly empty disk (cents a month, hours here). Expected total: 0.01 to
0.02 USD. The real figure is read the next day from the meters: two VM rows (one per size) should
appear, which is the observation of the resize.

## Before applying (free)

```powershell
az vm list-skus --location denmarkeast --size Standard_B2ats_v2 --query "[].{name:name,zones:locationInfo[0].zones,restricted:restrictions[0].reasonCode}" --output json
```

Expected: the size exists, zone `1` is listed and `restricted` is null. If it is restricted, stop: the
resize target would be refused as B1s was in East US 2.

```powershell
terraform fmt -check -recursive azure/layer1
terraform "-chdir=azure/layer1" init "-backend-config=backend.local.hcl"
terraform "-chdir=azure/layer1" validate
```

## 1. Build at B1s (expected 8 to add)

```powershell
terraform "-chdir=azure/layer1" plan -no-color "-target=azurerm_linux_virtual_machine.compute" "-out=build.tfplan"
terraform "-chdir=azure/layer1" apply -no-color build.tfplan
```

Note the UTC time at the start and end. State after: `VM running`.

## 2. Resize (expected 1 to change, 0 to destroy)

```powershell
terraform "-chdir=azure/layer1" plan -no-color "-var=vm_size=Standard_B2ats_v2" "-target=azurerm_linux_virtual_machine.compute" "-out=resize.tfplan"
```

Read the plan: `size` goes from `Standard_B1s` to `Standard_B2ats_v2` as an update in place. If it says
"must be replaced", stop. Then apply and check the size and the state:

```powershell
terraform "-chdir=azure/layer1" apply -no-color resize.tfplan
az vm show --resource-group rg-cloud-lab --name $vm --query hardwareProfile.vmSize --output tsv
az vm show --resource-group rg-cloud-lab --name $vm --show-details --query powerState --output tsv
```

Expected: `Standard_B2ats_v2` and `VM running`. The provider stops the VM to resize it; the activity log
shows the sequence.

## 3. Image (snapshot) (expected 1 to add)

```powershell
terraform "-chdir=azure/layer1" plan -no-color "-var=vm_size=Standard_B2ats_v2" "-target=azurerm_snapshot.compute" "-out=snap.tfplan"
terraform "-chdir=azure/layer1" apply -no-color snap.tfplan
az snapshot list --resource-group rg-cloud-lab --query "[].{incremental:incremental,sizeGb:diskSizeGb,state:provisioningState,domain:tags.domain}" --output tsv
```

Expected: `True`, `30`, `Succeeded`, `compute`. Pass `-var=vm_size=Standard_B2ats_v2` on every plan and
apply from here on, or Terraform will plan to resize back.

## 4. Teardown and verification

```powershell
& $bash scripts/teardown.sh azure
```

Pass the size variable here too if the script does not pick it up from the state; destroy does not need
it. Then, all empty:

```powershell
az resource list --resource-group rg-cloud-lab --query "[].type" --output tsv
az snapshot list --resource-group rg-cloud-lab --query "[].name" --output tsv
```

## 5. After

- Read every file in `evidence/` before committing.
- Next day: Cost Management by meter; expect two VM rows (B1s and B2ats_v2) plus a snapshot row. Record
  with its date in `docs/credit-log.md` and add the observation to `docs/study/compute-azure-vs-aws.md`.
