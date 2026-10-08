# Lab setup (from zero)

Working folder on the operator's machine: `C:\dev\cloud-lab`, deliberately outside OneDrive
(see `decisions/0001-working-folder-and-independence.md`).

## 1. Tools

- Git, Terraform >= 1.10, Azure CLI, AWS CLI v2.
- Record the exact versions used in `docs/lessons-learned.md` the first time something behaves differently.

## 2. Authentication (never written to a file)

- Azure: `az login`, then `export ARM_SUBSCRIPTION_ID=...` (PowerShell: `$env:ARM_SUBSCRIPTION_ID`).
- AWS: a named profile and `AWS_PROFILE`.

## 3. Layer 0 bootstrap, once per cloud

Follow `azure/bootstrap/README.md` and `aws/bootstrap/README.md`. Result: a state backend and a `backend.local.hcl` per cloud (gitignored).

## 4. Prove the destroy path

`scripts/teardown.sh azure` and `scripts/teardown.sh aws` against the empty layer 1. Review the output in `evidence/`, then commit.

## 5. Verify nothing leaks

```
git check-ignore -v azure/bootstrap/terraform.tfstate azure/layer1/backend.local.hcl aws/bootstrap/terraform.tfstate aws/layer1/backend.local.hcl
```

Each path must print the rule that ignores it.

## Rebuild log

Dated entries, newest last. Every deviation from the steps above goes here.


- 2026-10-07: tools installed with winget: Terraform 1.16.5, Azure CLI 2.91.0. `terraform fmt -check` and `validate` pass in all four roots; provider lock files committed (azurerm 4.81.0, aws 6.68.0, random 3.9.1, time 0.14.2).
- 2026-10-07: Azure layer 0 bootstrap applied (7 resources, East US 2). First Azure `destroy` against the empty layer 1: "Resources: 0 destroyed", output in `evidence/`. Bootstrap state backed up outside the repository and outside OneDrive.
