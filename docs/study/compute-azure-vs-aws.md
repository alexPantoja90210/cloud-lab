# Compute: Azure VM vs AWS Lambda, from one lab session

Scope: the CLOUD-28 session of 12 Oct 2026, built by hand in the consoles (the Terraform equivalent is not written yet). Everything marked **observed** comes from a command output or a console screen captured that day. Claims marked **[general]** come from general knowledge and must be checked against vendor documentation before they are quoted. Claims marked **[estimate]** are my own arithmetic on recalled list prices and are replaced by measured values once the next-day cost read is in (last section).

## Two different primitives for one objective

The objective is the same on both clouds: run some code that answers a request. The primitive is not, and that difference is the whole finding.

| | Azure | AWS |
|---|---|---|
| What was built | One `Standard_B1s` VM (Ubuntu Server 24.04 LTS), Denmark East, no public IP, no inbound ports | One Lambda function (arm64, 128 MB) behind an API Gateway HTTP API, us-east-1 |
| What you pay for | Every hour the VM is allocated, used or not | Each request and each millisecond of run time; nothing at rest |
| Why this primitive on this cloud | The free account includes B1s hours | The free plan allows only always-free offerings, so no EC2 was started (CLOUD-28 rule) |
| Tags | `lab`, `layer`, `domain` set in the wizard on every resource | Set on function, execution role and log group in the console; on the API through the CLI only |

## Timeline (observed)

Local time, UTC-6. Sources: deployment screen, Azure activity log, resource creation timestamps.

| Time | Event |
|---|---|
| 10:54:05 | VM deployment starts (the Network Watcher for the region was created at 10:54:15) |
| 11:19:57 | Azure Bastion (Basic) finishes creating; it was added by hand and was not in the plan |
| 11:39:40 | Bastion delete succeeds; its public IP was deleted separately afterwards |
| 12:35:48 | `az vm stop` starts |
| 13:53:00 | `az vm deallocate` starts (finished 13:53:10) |
| ~14:27 to 14:28 | Resource group deleted |

The `stop` ran about 40 minutes later than planned and the `deallocate` about 18 minutes later, so the hours below are the real ones, not the planned ones.

| State | From | To | Hours |
|---|---|---|---|
| Running | 10:54 | 12:35 | 1.70 |
| Stopped (Allocated) | 12:36 | 13:53 | 1.28 |
| Deallocated | 13:53 | ~14:27 | ~0.57 |

## What was observed

1. **Stopped is not off.** After `az vm stop` the CLI printed "It will continue to be billed. To deallocate a VM, run: az vm deallocate." The CLI reported `VM stopped` and the portal showed "Detenido". Only after `az vm deallocate` did the CLI report `VM deallocated`. Whether the billing difference shows up in the cost data is read the next day (last section).
2. **The catalog and the wizard disagreed.** The portal size picker showed `Standard_B1s` as "No disponible" in several regions (East US 2 carried the code `NotAvailableForSubscription`). The CLI listed `Standard_B1s` in Denmark East with no restrictions and zones 1, 2 and 3. Later `B1s` became selectable in Denmark East (zone 1) at a list price of 8.76 USD a month, 0.0120 USD an hour, with the note that subscription credits apply. Which wizard setting made it selectable was not isolated.
3. **Denmark East does not support auto-shutdown.** The portal said so next to the checkbox, and the one attempt to add a schedule appears in the activity log as `Add or modify schedules` with status `Failed`. Nothing was created. The VM therefore had no safety net and the stop was manual.
4. **Lambda reports its own billing.** The first invocation printed `Duration: 2.05 ms`, `Billed Duration: 98 ms`, `Init Duration: 95.72 ms`, `Memory Size: 128 MB`, `Max Memory Used: 37 MB`. The billed time is the run time plus the cold start, rounded up (2.05 + 95.72 = 97.77, billed 98). The cold start is billed.
5. **The endpoint worked.** Ten calls to the API returned ten `200`.
6. **The console allowed two APIs with the same name.** The API Gateway form says names do not have to be unique, and two APIs named `cloud-lab-hello-API` existed. One had a route but was not listed as a trigger of the function, so it had no permission to invoke it. It was an orphan from a half-finished first attempt and was deleted; the other kept answering `200`.
7. **The console did not offer tags for the HTTP API.** `aws apigatewayv2 tag-resource` worked and `get-tags` returned the three tags.
8. **Defaults that outlive the resource.** The function's log group was created by Lambda, outside any plan, with retention "No vence nunca". The execution role is also created automatically. Deleting the function deletes neither.
9. **A shared role was tagged by mistake.** `AWSServiceRoleForAPIGateway` is created once per account by AWS and is not part of the lab. It was tagged with `lab=cloud-bal` (a typo); the tags were removed.

## What went wrong, and what it taught

- **A Bastion was created by hand to connect to a VM that had no public IP.** It was a Basic SKU, untagged, and it bills for every hour it exists, connected or not. It lived about 20 minutes (11:19:57 to 11:39:40), which is shorter than the 30 to 60 minutes first assumed. It was found because the operator noticed the cost, not because a check caught it. Rule for the risk register: anything that bills by the hour is tagged and has a deletion time before it is created.
- **A second `Delete Public Ip Address` event appears in the activity log at 11:51**, ten minutes after the first. It is not explained. The resource listing showed no public IP afterwards.
- **I said the subscription should be empty after the teardown.** It was not, and it should not have been: layer 0 (the Terraform state storage account and a managed identity, both `layer=0`) stays by design. The right check is "empty of layer 1".
- **One unrelated resource turned up** (an Azure AI Foundry account and project, created 1 Oct, before the sprint, untagged). The operator confirmed it was an old experiment and deleted it at 14:35. Nothing else outside layer 0 and two free Network Watchers remains.

## Configured but not observed

- **The Terraform build.** CLOUD-28 asks for a VM built, resized, imaged and destroyed from Terraform. The 12 Oct session was console-only, by decision. The Terraform twin was written and syntax-checked on 13 Oct (`azure/layer1/compute.tf`, `aws/layer1/compute.tf`, session steps in `docs/runbooks/compute-session.md`) but has not been planned or applied, so nothing in it is observed yet. Resize and image capture are not covered.
- **Free-hours consumption.** The 750-hour allowance was read at 0 hours of B1s before the session (12 Oct, 09:59). The 13 Oct read shows 2.983 hours of B1s priced at the full list rate, with no zero-priced meter for B1s. Whether the free-hours benefit or the credit paid for them is not visible in that gross view and is still open.
- **Cost at zero traffic on AWS** is observed on the 14 Oct read (section below): a full day with the stack in place and no calls produced no Lambda or API Gateway line.
- **Disaster recovery and migration.** Planned in CLOUD-33, CLOUD-34 and CLOUD-35, not started.

## Cost

### Expected, to be checked against the read of 13 Oct

| Item | Expected | Basis |
|---|---|---|
| VM compute | about 2.98 h (1.70 + 1.28), about 0.036 USD at 0.0120 USD/h | Activity log times and the price shown in the wizard |
| VM compute if Deallocated also billed | about 3.5 h | Would mean the Deallocated stretch cost something |
| Bastion | about 0.33 to 0.45 h, about 0.06 to 0.09 USD **[general]** at about 0.19 USD/h (recalled list price) | Times from the activity log |
| One Lambda invocation (cold, 98 ms, 128 MB, arm64) | about 0.0000004 USD **[estimate]** | Recalled list prices |

### The crossover **[estimate]**

Assumptions, all to be checked: VM B1s running all month about 8.76 USD plus a 30 GB Standard SSD at about 2.4 USD, so about 11 USD; Lambda about 0.37 USD per million requests at 100 ms and 128 MB; API Gateway HTTP about 1.00 USD per million requests; no free tiers subtracted; the workload fits in functions.

| Requests per month | Lambda + API Gateway | Share of the VM cost | Saving |
|---|---|---|---|
| 100 thousand | about 0.14 USD | about 1% | about 99% |
| 1 million | about 1.4 USD | about 12% | about 88% |
| 5 million | about 6.8 USD | about 62% | about 38% |
| 8 million | about 11 USD | about 100% | none (crossover) |
| 10 million | about 13.7 USD | about 125% | Lambda costs more |

Without API Gateway (a function URL instead) the crossover moves to about 30 million requests a month. The service that exposes the function can cost more per request than the function itself.

## The migration question

What would have to change to move a workload from the VM to Lambda is code, not configuration: this is a refactor, not a rehost. A service is a candidate when it is mostly idle, short (well under 15 minutes per run), stateless, and free of operating-system dependencies. Typical candidates: scheduled jobs, webhook receivers, file processing on upload, queue consumers, cost-governance scripts, token validation. Poor candidates: databases, long-running or connection-holding services, jobs over 15 minutes, anything with local state, and services with steady high traffic above the crossover. The rewrite effort is not in the percentages above and belongs in the plan of CLOUD-33 and CLOUD-34.

## Azure read, 13 Oct 2026 (observed)

Read about 16:04 local, 22 hours after the teardown: usage quantity and cost for the month to date, grouped by service and meter, from the Cost Management query API. The cost is gross (credits are not applied in this view). Rows that belong to the 12 Oct session:

| Meter | Quantity | Cost (USD) | Expected |
|---|---|---|---|
| Virtual Machines, B1s | 2.983 h | 0.0358 | about 2.98 h: matches |
| Storage, E4 LRS Disk | 0.004755 month (about 3.5 h) | 0.0114 | the disk existed from 10:54 to about 14:27 |
| Storage, E4 LRS Disk Operations | 1.12 | 0.0022 | not estimated |
| Virtual Network, Standard IPv4 Static Public IP | 0.787 h | 0.0039 | **does not match**, see point 4 |
| Azure Bastion | no row | none | about 0.33 to 0.45 h |

The rows above add up to about 0.053 USD.

1. **The hours billed match the activity log.** 2.983 h billed against 2.98 h expected (1.70 Running + 1.28 Stopped (Allocated)). Without the Stopped (Allocated) stretch the figure would be 1.70; if Deallocated had also billed it would be about 3.5. So Stopped (Allocated) billed and Deallocated did not. The price is exactly 0.0120 USD an hour (0.0358 / 2.983).
2. **The cost view cannot split Running from Stopped (Allocated).** Both land in the same meter. The evidence is the total, not a separate line.
3. **The disk kept billing while the VM was stopped and deallocated.** Its quantity (about 3.5 hours) is consistent with the whole life of the VM, Deallocated stretch included, at 2.40 USD a month. This matches the estimate used in the crossover table.
4. **The public IP meter does not match.** 0.787 hours billed (0.005 USD an hour) against a Bastion that existed about 0.33 hours. The VM was created with no public IP, the Bastion needs one, and the activity log shows two `Delete Public Ip Address` events (11:41 and 11:51). I could not reconstruct the lifetime of each IP from the data available. Open, and worth only 0.0039 USD.
5. **No Azure Bastion row exists yet.** The most likely cause is posting delay, but that is a guess: the absence is not evidence that it was free. Read again on 14 Oct.
6. **The 750 free hours are not visible.** B1s is priced at the list rate and no meter for it carries a "Free" suffix, unlike several storage meters. This read cannot say whether the benefit or the credit paid for the hours.
7. **The only Foundry line is usage, not idle cost.** `text-embedding-3-large-regional Tokens`, 300.801 units, 0.043 USD, already present in the 12 Oct baseline. The account was deleted on 12 Oct.
8. **The private endpoint meter is unchanged** at 0.8539 hours, as in the 12 Oct read.

## AWS read, 14 Oct 2026 (observed)

Read about 09:04 local with Cost Explorer: unblended cost, credits excluded, 12 and 13 Oct, services Lambda, API Gateway and CloudWatch, grouped by tag `domain` and usage type. One call, about 0.01 USD.

| Day | Tag `domain` | Usage type | Quantity | Cost (USD) |
|---|---|---|---|---|
| 12 Oct | none | `USE1-ApiGatewayHttpRequest` | 11 | 0.000011 |
| 12 Oct | compute | `Request-ARM` | 12 | 0 |
| 12 Oct | compute | `Lambda-GB-Second-ARM` | 0.04225 | 0 |
| 12 Oct | compute | `USE1-VendedLog-Bytes` | 0.0000044 | 0 |
| 12 Oct | none | `DataTransfer-Out-Bytes` | 0.0000018 | 0 |
| 13 Oct | compute | `USE1-TimedStorage-ByteHrs` | 0.00000008 | 0 |

1. **Cost at zero traffic was 0 USD.** On 13 Oct the function, API, role and log group existed all day and nobody called them. The only line is log storage, at 0 USD, and there is no Lambda or API Gateway line. The 13 Oct data may not have been complete at read time (the day had closed about 15 hours earlier and Cost Explorer can lag up to 24).
2. **API Gateway was the only line that cost anything, and its price is confirmed.** 11 requests cost 0.000011 USD, exactly 1.00 USD per million, as assumed. Lambda's 12 requests and 0.04225 GB-seconds fell inside the always-free allowance. At recalled list prices they would have cost about 0.000003 USD, so the gateway charge was about 4 times the function's.
3. **The API Gateway usage is untagged.** The API got its tags at 13:05; the ten calls and the check call ran at 12:50 and 13:02. A tag does not reclassify usage that happened before it. Lambda was tagged from creation and is classified. Terraform tags the API when it creates it.
4. **The 100 ms per request assumed in the crossover table was higher than what this function did.** 0.04225 GB-seconds at 128 MB is 338 ms billed over 12 invocations, about 28 ms each, of which 98 ms was the first (cold) one. A trivial function, so Lambda compute is cheaper than assumed; the crossover barely moves because API Gateway dominates the per-request cost.
5. **Log lines cost 0 at these sizes** (vended log bytes and timed storage).

The paid AWS cost of the whole 12 Oct session was 0.000011 USD; about 0.000014 USD at list prices with the allowance removed.

## Azure re-read, 14 Oct 2026 (observed)

Same Cost Management query as 13 Oct (12-14 Oct, gross cost, grouped by service and meter), read at about 09:18 local.

- Virtual Machines B1s: 2.983 hours, 0.0358 USD. Identical to the 13 Oct read.
- Standard IPv4 Static Public IP: 0.787 hours, 0.0039 USD. Identical to the 13 Oct read.
- E4 LRS Disk: 0.004755 month, 0.0114 USD; disk operations 0.0022 USD. Unchanged.
- Still no Azure Bastion row, two days after the 11:19-11:39 deployment on 12 Oct.

So the numbers are stable, not lagging, and the Bastion is missing from this query. Not explained. Hypothesis (not verified): the Bastion was billed under a different service name or date, or the line has not been posted yet.

Public IP hours: 0.787 h is close to the VM's own IP living from deployment (10:54) to its deletion (11:41), about 0.78 h. If so, the Bastion's IP is not in this meter either. This fits the two `Delete Public Ip Address` events (11:41 and 11:51) but does not prove it.

## AWS console stack teardown, 14 Oct 2026 (observed)

HTTP API, Lambda function, log group and execution role are gone (list and get calls return empty). One customer-managed policy named like the Lambda basic execution policy remains: created 28 Sep, 0 attachments, so it predates this lab and was left alone. The service-linked role for API Gateway is account-level and stays.

## Still to read

| Reading | Status |
|---|---|
| Azure Bastion row and the public IP discrepancy | reread 14 Oct: row still absent, IP hours unchanged; open |
| Where the free hours show up (charge type) | open |
| Lambda and API Gateway per-request cost, measured | done: see the AWS read |
| AWS cost at zero traffic | done: 0 USD |

The console-built AWS stack was deleted by hand on 14 Oct (see above).
