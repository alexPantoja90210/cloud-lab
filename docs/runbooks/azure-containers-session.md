# Azure containers session: Container Apps and AKS (hand-built)

Date: 22 Oct 2026. Jira: CLOUD-44, Azure phase 3 (3A Container Apps, 3B AKS).
Region: eastus2. Everything was created by hand with the Azure CLI and removed the same morning.
Resource group `rg-cloud-lab` was verified empty at the end (0 resources, 0 `MC_*` node resource groups).

## Run table

| Step | Result | Seconds |
|---|---|---|
| Container Apps environment create (consumption, no Log Analytics) | Succeeded | 939 |
| Container App create (sample hello-world image) | Succeeded | 19 |
| Warm requests (3 samples) | 0.46 / 0.23 / 0.18 | n/a |
| Cold start from zero replicas | 24.2 s to first response | 24.2 |
| Container App delete | Succeeded | 18 |
| Container Apps environment delete | ScheduledForDelete, then gone | about 1740 (estimate, 10:23 to 10:52 local) |
| AKS create (Free tier, 1 node D2als_v7, k8s 1.36) | Succeeded | 359 |
| Deployment, 2 replicas, same sample image | Ready | 2 |
| Delete one pod, wait for a healthy replacement | Replaced | 2.8 |
| Public endpoint (Service type LoadBalancer) | HTTP 200, first request 1.17 s | n/a |
| AKS delete | Succeeded, node resource group removed | 278 |

Not captured in this first run: time for the public IP to be assigned and the time Container Apps takes
to scale back to zero. Both were measured in the second run below.

## Cost

Prices read from the public Azure retail price API (eastus2):

| Item | Price |
|---|---|
| D2als_v7 node | 0.0804 USD/h |
| Standard load balancer, included rules | 0.025 USD/h |
| Standard load balancer, data processed | 0.005 USD/GB |
| Standard IPv4 static public IP | 0.005 USD/h |
| AKS Free tier control plane | 0 |

- AKS expected cost while it existed: about 0.12 USD/h plus about 0.005 USD/h while the public service existed.
  The cluster lived about 22 minutes, so roughly 0.05 USD. Estimate only; the real figure comes from Cost Management
  after the billing lag and is not recorded here yet.
- Container Apps stayed inside the monthly free grant (180,000 vCPU-s, 360,000 GiB-s, 2M requests).
  `--logs-destination none` avoided any Log Analytics charge.

## Findings

1. AKS creates its load balancer and an outbound public IP by default. They are billed even if you never publish a service.
2. Container Apps environment creation was slow (939 s) and deletion was slower still. Plan for about 45 minutes round trip.
   The environment shows `ScheduledForDelete` for a long time; that is normal, do not repeat the delete.
3. Scale from zero costs real latency: 24.2 s cold versus 0.18 s warm. A Kubernetes pod replacement on a warm node took 2.8 s.
4. AKS needs a node (cost per hour while it exists); Container Apps costs nothing while idle inside the free grant.
5. The AKS "ready" in the 2 s deployment test means the container started. The sample has no readiness probe.
6. After deleting the cluster, one resource briefly remained in the resource group and disappeared a few minutes later.
   Always re-count before declaring the teardown clean.

## Caveats

- Single run each, one node, one region. These are first-run numbers, not benchmarks.
- The 2 s deployment time depends on the image being small and the node pulling it quickly.
- kubectl and kubelogin were installed in `%USERPROFILE%\.azure-kubectl` for this session only.
  The kubeconfig was written to a temp file and deleted.

## Mistakes

- My estimate for the Container Apps environment create was 2 to 4 minutes; it took 939 s.
- My first load balancer price queries returned nothing because the meters are published with region `Global`.

## Terraform twin of AKS (`azure/aks`)

Same shape as the hand-built cluster: Free tier, one D2als_v7 node, system-assigned identity,
Azure CNI overlay, standard load balancer, nothing else enabled. Own state key, cluster name `aks-cloud-lab-tf`.

| Step | Result | Seconds |
|---|---|---|
| `terraform validate` | valid on the first try | n/a |
| `terraform plan` | 1 to add | n/a |
| `terraform apply` | 1 added, node Ready, 0 system pods failing | 224 |
| `terraform destroy` | 1 destroyed, resource group empty, 0 node resource groups | 395 |

- Hand-built create took 359 s and delete 278 s; the twin took 224 s to create and 395 s to destroy.
  One run each, so these differences are not conclusions.
- Terraform removes the whole cluster in one command and the resource count returned to 0 immediately
  (the hand-built delete briefly left one resource behind).
- Cost: the cluster existed about 10 minutes, roughly 0.02 USD by the price table above. Real figure pending Cost Management.

## Second run: Terraform only, inspected in the console (same day)

Why: the first run was built and destroyed by hand without the console being looked at. This run was created with
Terraform (`azure/aks`, `azure/containerapps`), reviewed in the portal, then destroyed.

| Step | Result | Seconds |
|---|---|---|
| AKS apply (Free tier, 1 node), then 2-replica deployment and a LoadBalancer service | public IP assigned, HTTP 200 | IP in 13 |
| Container Apps apply (environment plus app, scale 0 to 1) | 2 added | 97 |
| First request right after create | 0.3 s (a replica was still alive; not a cold start) | n/a |
| Scale to zero after my last request | 0 replicas in under about 2 minutes (only minute-level timestamps) | n/a |
| Cold request from zero replicas | HTTP 200 | 25.84 |
| Container Apps destroy | 2 destroyed | 724 |
| AKS destroy | 1 destroyed, 0 node resource groups left | not captured |

What the portal showed (node resource group `MC_...`, ordered by type):
1 virtual machine scale set, 2 public IP addresses, 1 load balancer, 1 network security group,
1 managed identity, 1 virtual network. There is no separate disk resource, so the 0.01 USD disk
estimate in the cost table is unverified.

Public IPs, checked live: one has a long identifier as its name and is the cluster's outbound IP, billed even
if nothing is published. The other is named `kubernetes-<hash>` and is created by the Service of type
LoadBalancer. Deleting the Service removed it; recreating the Service produced a new one with a different name.

Observations:

1. Container Apps by Terraform took 97 s to create against 939 s by hand. Unexplained. Two untested hypotheses:
   first environment in the region or subscription is slower, or normal variance. One sample each.
2. The Container Apps API returns no `minReplicas` when it is 0 (the default), so the CLI shows it empty.
3. Scale to zero was much faster than the roughly 5 minutes I expected. Cold start from zero was 25.84 s,
   consistent with 24.2 s in the first run.
4. Container Apps destroy by Terraform took 724 s; the hand-built environment took about 29 min to delete (estimate).
5. The portal was in Spanish, so menu names differed from the English ones used in the instructions.
   Checking values by CLI settled what the portal screens meant.
6. AKS cost for this run: the cluster existed roughly 35 minutes, about 0.08 USD by the price table. Estimate;
   the real figure comes from Cost Management.

## Measured cost, 22 Oct 2026 (read by CLI on 23 Oct)

Total 0.12289 USD for the day against an estimate of about 0.15.

| Meter | Estimate | Measured |
|---|---|---|
| D2als v7 node | 0.0804 USD/h | 0.07102 USD for 0.883 h (matches the rate) |
| OS disk (P10 LRS, 128 GiB default) | about 0.01 | **0.03690**, the second largest line |
| Standard public IPv4, static | 0.005 USD/h | 0.01493 for 2.99 h (hours not explained) |
| Load balancer rules | 0.025 USD/h | **0.0**, billed under a "Free" meter for 2.26 h |
| Data transfer and operations | about 0 | 0 |

Corrections to the findings above: the AKS node disk does bill, as its own meter, even though no disk
resource appears in the node resource group; and the load balancer rules were not charged, although the
retail price list shows 0.025 USD/h. No Container Apps meter appeared at all, so "inside the free grant" is not
confirmed by this reading. To re-read after the billing lag. The portal reading by Alex is still to be recorded.

## Next

- CLOUD-44: Container Apps Terraform twin is optional; the environment takes about 15 min to create and 30 min to delete.
- Read the real cost of this session in Cost Management once the billing data has landed.
