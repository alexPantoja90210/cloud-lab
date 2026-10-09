# Cost: Azure vs AWS, from one lab session

Scope: what was set up and read on 8 and 9 Oct 2026 (CLOUD-25), plus general knowledge where marked **[general]**. General-knowledge claims were not tested in this lab and should be checked against the vendor documentation before they are quoted. This note is provisional: the AWS cost reading and the attribution to a single resource are still open (see the last section).

## The same job, two models

The lab did the same thing on both clouds: define one tag scheme in Terraform (`lab`, `layer`, `domain`, see `docs/tagging.md`), deploy a tagged probe, destroy it, and read what the bill says about it.

| | Azure | AWS |
|---|---|---|
| How tags are applied | A `locals.tags` map set on each taggable resource | `default_tags` on the provider, plus per-resource tags where one domain differs |
| Step needed before tags show in cost data | None observed. Cost analysis grouped by `domain` showed `identity`, `foundation` and untagged on 9 Oct | Each key must be activated as a cost allocation tag in Billing. `lab` and `layer` were listed (inactive) and activated on 8 Oct 13:45 local; `domain` was not in the list on 9 Oct 08:40 local, appeared as inactive at about 09:00 and was activated on 9 Oct |
| Who can open the cost pages | The operator's own user | An IAM user got "IAM user access not activated" until the account root switched the billing-access setting on, once |
| What the cost view reported at this scale | Cost analysis, 7 to 9 Oct: total under 0.01 USD; each tag group under 0.01 USD | Not read yet. The console credit balance went from 175.04 to 174.88 USD between two readings, which covers all usage in between |
| Resolution at tiny amounts | Two decimals: anything under a cent shows as "<$0.01", so groups cannot be compared with each other | Not read yet |

## Where the two genuinely differ

1. **Azure showed tags without an activation step; AWS makes activation a deliberate act.** Observed on Azure: the `foundation` and `identity` groups appeared in a report without any extra setup. Observed on AWS: tags have to be activated, and the list only offers keys it has already seen. **[general]** AWS documents that activation is not retroactive, so spend before activation is not classified by that tag. This lab has not yet seen that for itself.
2. **Two views on the same cloud disagreed in resolution.** On Azure the credits page kept showing 0.04 USD month to date across three days, while Cost analysis for 7 to 9 Oct showed a total under 0.01 USD. They are consistent (the 0.04 predates the lab), but only Cost analysis can say "under one cent". Do not read the credits page as a cost meter.
3. **Directly tagged resources reach cost records; resource group tags may not.** Observed: resources tagged from Terraform appeared in the report grouped by tag. **[general]** Azure documents that a resource group's tags do not flow to its resources' cost records unless tag inheritance is enabled in Cost Management. This lab tagged resources directly and did not test inheritance.
4. **The untagged group is a record of history, not an error.** The CLOUD-24 probe ran before `domain` existed, so its cost sits in the untagged group on Azure. A tag scheme classifies spend from the day it is applied.

## What each one could not tell us here

- Azure: which specific resource the cost belongs to. A by-service grouping was read on 9 Oct (see below); a by-resource grouping was not.
- AWS: anything about cost, beyond the credit balance. Cost Explorer (unblended, by service and by tag) was not read.
- Both: the size of the difference between container instances and storage for the probe. At under one cent, the bill cannot rank them.

## Still open

- AWS: `domain` is activated (9 Oct). Read Cost Explorer by service and by tag (unblended) after the storage session, which is the first usage classified by `domain`.
- Both: attribute one day's cost to a specific resource and record it with its read date.
- Update this note, and tick the AWS cost bullet in `docs/study/identity-aws.md`, when those readings exist.

## Azure by tag and service, read on 9 Oct 2026

Actual cost for 7 to 10 Oct, grouped by `domain` and service (Cost Management query, free to call): Container Instances 0.0018 USD (0.0007 tagged `identity`, 0.0011 untagged from the earlier probe), Storage 0.0001 USD (`foundation` and untagged), Bandwidth 0. Total about 0.0019 USD. Container Instances is about 95 percent of it, so for the identity probe the container group, not the storage account, was the cost. No `storage` row exists yet because the CLOUD-26 usage had not been reported; it is read again on 10 Oct. This is attribution to a service, not to a single resource.
