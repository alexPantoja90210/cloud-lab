# Azure close-out (CLOUD-30)

Written 2 Nov 2026. Records the state of the Azure side after the free credit expired, whether a clean clone can rebuild
the work, and what was not done. Nothing here contains a subscription, tenant or resource identifier.

## State on 2 Nov 2026

- The free-trial credit expired about 31 Oct. The portal home page says the trial expired, services are paused, and the
  account will be deleted on 30 Nov 2026. Read by the operator in the portal on 2 Nov.
- Billing accounts page: the Azure subscription shows status Disabled, next invoice N/A. The Microsoft Entra ID Free
  directory shows Active (free).
- Cost, from the Cost Management API: 24 to 26 Oct total 0 USD (only a free-tier storage quantity). Month to date
  about 0.38 USD gross, before credits. See `docs/credit-log.md`.
- The lab resource group was verified at 0 resources on 23 Oct. The spending limit was not removed and the
  subscription was not upgraded.
- Not recorded: a final credit balance. The last balance read is 21 Oct (199.80 USD available, about 10 days left).
  After expiry the portal no longer offers a comparable figure, so this criterion is closed with the 21 Oct read plus
  the cost reads above, not with a final balance.

## Clean clone

Date: 2 Nov 2026. A fresh clone of the public repository was made in a temporary folder, and for each of the nine
Terraform folders `init -backend=false` and `validate` were run. Result: all nine returned 0 for both.

| Folder | init | validate |
|---|---|---|
| aws/bootstrap, aws/identity, aws/layer1 | 0 | 0 |
| azure/aks, azure/bootstrap, azure/containerapps | 0 | 0 |
| azure/departments, azure/identity, azure/layer1 | 0 | 0 |

Also checked on the clone: no state, plan or per-operator variable files are tracked; no identifier of the UUID shape
appears in `.tf`, `.md`, `.hcl` or `.ps1` files.

What this does not show: **`plan` was not run, and cannot be run for Azure any more.** The Azure folders (except
`azure/bootstrap`, whose state was local) keep their state in a storage account that lives in the deleted subscription
(automatic deletion on 30 Nov). A clean clone can validate the Azure code but cannot plan or apply it without a new
subscription and a new state backend. The AWS folders keep their backend on AWS, which is unaffected. So the acceptance
criterion "a clean clone produces a plan that would rebuild the month's work" is met for AWS in principle and was
not tested as a plan in this check; for Azure it is met only up to `validate`.

## What was not done

- **Monitoring on Azure (CLOUD-29, Azure half).** Not started before the credit expired: no metric alert, no Log
  Analytics workspace, no KQL query, no measured alert delay. The comparison note for monitoring cannot claim any of it.
  The AWS half has not been built either; the AWS account is still active (see the AWS close-out ticket for its date).
- **CLOUD-44, Azure phase 3 only.** Container Apps and AKS were built by hand and from Terraform, inspected in the
  console and destroyed. Phases 1, 2, 4 and 5 of that ticket were not done, and parts of its acceptance criteria stay
  open (see the ticket).
- **Unexplained measurements, left open:** Container Apps environment creation took 939 s by hand and 97 s by
  Terraform; the AKS node was billed 0.0667 h on 23 Oct against a longer cluster lifetime; public IP hours exceeded node
  hours on 22 and 23 Oct; the load balancer rules meter billed 0 although the price list shows a rate; no Container Apps
  meter appeared in any cost read; a failing readiness probe and the time to the first ErrImagePull on AKS were not
  measured.
- **Final credit balance:** see above.
- **Terraform state on Azure:** the remote state is lost with the subscription; the local state of `azure/bootstrap`
  was kept only on the operator's machine.
