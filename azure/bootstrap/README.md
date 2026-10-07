# Azure layer 0 bootstrap

Creates, once: the empty lab resource group, the state resource group, a storage account (Entra ID auth only, versioned) and the `tfstate` container.

State for this folder is **local** (chicken-and-egg: the backend cannot store its own creation). The local `terraform.tfstate` is gitignored. Losing it only means re-importing four resources; keep a copy outside the repository.

```
az login
export ARM_SUBSCRIPTION_ID="<from az account show>"   # in your shell, never in a file
terraform -chdir=azure/bootstrap init
terraform -chdir=azure/bootstrap apply
terraform -chdir=azure/bootstrap output -raw backend_config > azure/layer1/backend.local.hcl
git check-ignore -v azure/layer1/backend.local.hcl azure/bootstrap/terraform.tfstate
```

Cost: a storage account holding kilobytes of state, cents per month. No hourly meters.
Every resource has `prevent_destroy`; running `destroy` here fails on purpose.
