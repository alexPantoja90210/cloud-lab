# Azure networking, second hand-built run (CLOUD-27), 21 Oct 2026

**This repeated work that was already done.** The Azure half of CLOUD-27 was built by hand in the console on 15 Oct 2026 and applied and destroyed in Terraform on 16 Oct (see `docs/study/networking-azure-console.md` and `docs/runbooks/networking-session.md`). The 21 Oct run happened because the plan for the day was made without reading those files first. It is kept as a second, independent run with its own predictions; the findings that are new compared with the first run are listed at the end.

Region East US 2 (the region of the existing storage account). Operator built the pieces in the portal from written steps; the CLI was used only to read and verify. Times are local (UTC-6). Cost figures are estimates until the Cost analysis lag has passed.

## What was built, in order

| Time | Piece | Notes |
|---|---|---|
| about 09:20 to 09:25 | Virtual network, address space 10.20.0.0/16, subnets `web` 10.20.1.0/24 and `db` 10.20.2.0/24 | The review screen showed region East US, not East US 2; caught before Create and fixed. Review screen showed no price. Both subnets are "private" (default outbound access off). The CLI field `addressPrefix` returned None; the current field is `addressPrefixes` |
| about 09:33 | NSG `nsg-web`, associated with subnet `web` | Free. Default rules read by CLI: AllowVnetInBound 65000, AllowAzureLoadBalancerInBound 65001, DenyAllInBound 65500; AllowVnetOutBound 65000, AllowInternetOutBound 65001, DenyAllOutBound 65500 |
| about 09:40 | Outbound rule `deny-web-to-db-443`, priority 100, TCP 443 to 10.20.2.0/24 | Created by hand with action **Allow** (portal default, not changed); found by reading it back with the CLI; corrected to Deny at 09:42 |
| 10:11 | Private endpoint to the storage account (blob), subnet `db`, with a private DNS zone | Address 10.20.2.4 (Azure reserves .0 to .3). Review screen showed no price. Network policies on the subnet: disabled, so NSG rules do not apply to traffic arriving at the endpoint; the deny rule works because it sits on the client side (outbound of `web`) |
| 10:26 to about 10:49 | Client VM in `web`, no public IP, driven with Run Command | Standard_B1s: SkuNotAvailable in eastus2 (no B sizes listed there at all). Standard_D2als_v7 (2 vCPU, 4 GB) at 0.0804 USD/h read from the public retail prices API; it had quota. Deleted with its disk and NIC; counts verified (0 VMs, 0 disks, 1 NIC = the endpoint's) |

## Predictions written before each step, and what happened

| Question | Prediction | Observed |
|---|---|---|
| Can `web` talk to `db` by default? | No | Yes: AllowVnetInBound and AllowVnetOutBound (65000) allow all traffic inside the virtual network |
| Price of the virtual network | "cents" | Review screen shows no price; the network itself looks free |
| Address of the endpoint | from the db range | 10.20.2.4 |
| Name of the storage account seen from the VM | 10.20.2.4 | 10.20.2.4 (private DNS zone works) |
| Connection to the endpoint on 443 with the deny rule | denied | `HTTP=000`, curl exit 28, "Connection timed out after 10000 ms": the NSG drops packets silently |
| Same request with the rule flipped to Allow (control) | not asked | `HTTP=400`: the storage answered, so the rule was the cause and the private path works. Rule restored to Deny and read back |
| Public path to the account from the operator's PC, public network access on, plain request to the account root | not asked | `HTTP=400` |
| Same with public network access turned off for about 40 s | not asked | still `HTTP=400`: inconclusive (the root URL without an operation is rejected as malformed before the network rule is checked, most likely; propagation delay not fully excluded) |
| Valid request (`?comp=list`), access on | not asked | `HTTP=409 PublicAccessNotPermitted` (the storage was reached) |
| Same, access off | refused | `HTTP=403 AuthorizationFailure` at the first check (15 s) |

Public network access was turned off only for seconds, in a block with a `finally` that turned it back on; read back as Enabled after each run. The account sits in the resource group `rg-cloud-lab-state`, which suggests it holds Terraform state (not confirmed by the operator), so it was never left disabled.

## Cost

- Private endpoint: created 10:11, still running at the time of writing; about 0.01 USD/h from the ticket and the 0.04 USD line seen in Cost analysis (inference).
- VM: about 23 minutes at 0.0804 USD/h, about 0.03 USD, plus a few thousandths for the 30 GB standard disk.
- Virtual network, subnets, NSG, NIC: no price shown, expected 0. Private DNS zone: cents per month.
- To read in Cost analysis (the grouping by meter, not before 22 Oct): D2als v7 vCPU, Standard Private Endpoint, Private Zone, the disk.

## What this taught

- Read back what you created: the rule named "deny" was an Allow.
- NSG rules are evaluated by priority, lowest number first; the defaults at 65000 and up allow everything inside the virtual network, so a deny has to be written.
- A silent timeout, not a refusal message, is what an NSG deny looks like.
- A control (flip the rule, repeat the request) is what separates "denied by the rule" from "unreachable for another reason".
- For storage tests, an invalid request can fail earlier than the check being tested.
- Capacity restrictions are per size and per region: B1s was unavailable in eastus2 while the D v7 family was.

## Left to do for this half

- Delete the endpoint, the DNS zone and links, the virtual network and the NSG (layer 1 empty), then the Terraform twin applied and destroyed, and the cost compared with the Cost analysis view.

## New compared with the 15 and 16 Oct runs (to check against them before treating as new)

- Subnets created in the portal on 21 Oct had "private subnet" (default outbound access off) enabled by default.
- `Standard_B1s` was not offered in `eastus2` for this subscription at all; the 15 and 16 Oct runs used another region. Capacity is per size and region.
- A control (flip the rule to Allow, repeat) separated "denied by the rule" from "unreachable".
- For the storage test, a plain request to the account root answered `400` whether public access was on or off; a valid `?comp=list` gave `409` on and `403 AuthorizationFailure` off.
- The rule created in the portal came out as Allow although it was named deny.
