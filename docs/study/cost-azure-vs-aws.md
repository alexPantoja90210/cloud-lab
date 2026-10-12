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

- Both: attribute one day's cost to a specific resource (a by-resource grouping), and record it with its read date. Only service and tag level were read.
- Optional: the AWS budget showed 0.72 USD on 9 Oct, accumulated before the 9 to 11 Oct window read below. A by-service reading for 1 to 8 Oct would say what it was; not done.

## Azure by tag and service, read on 9 Oct 2026

Actual cost for 7 to 10 Oct, grouped by `domain` and service (Cost Management query, free to call): Container Instances 0.0018 USD (0.0007 tagged `identity`, 0.0011 untagged from the earlier probe), Storage 0.0001 USD (`foundation` and untagged), Bandwidth 0. Total about 0.0019 USD. Container Instances is about 95 percent of it, so for the identity probe the container group, not the storage account, was the cost. No `storage` row exists yet because the CLOUD-26 usage had not been reported; it is read again on 10 Oct. This is attribution to a service, not to a single resource.

## Both clouds by tag, read on 12 Oct 2026

**AWS** (Cost Explorer API, unblended, by `domain`, 9 to 11 Oct): on 9 Oct foundation 0.00008 USD, storage 0.00006, identity 0.00005, and an untagged line of -0.00019 that cancels them (the credit being applied). On 10 and 11 Oct only foundation remains, about 0.0000001 USD a day. The tag `domain` classifies usage from 9 Oct on, as expected for a tag activated that day.

**Azure** (Cost Management query, actual cost, by `domain` and service, 7 to 12 Oct): total 0.0117 USD. By `domain`: storage 0.00854, identity 0.00189, untagged 0.00118, foundation 0.00005. By service: Virtual Network 0.0085, Container Instances 0.0030, Storage 0.0001, Bandwidth 0.

**What the two readings say together.** For the CLOUD-26 storage session the AWS side cost about 0.00006 USD and the Azure side about 0.0085 USD, but they are not the same thing: almost all of the Azure figure is the Virtual Network line, and the only network resource that session created on Azure was the private endpoint, which has no counterpart on the AWS build. The Azure storage account itself cost about 0.000004 USD. Comparing the storage services themselves, both are fractions of a cent; the visible cost difference came from one optional networking resource, not from the storage. **[general]** Azure documents private endpoints as billed hourly, so a few minutes of use can be billed as a full hour; the amount here is below that, and this lab did not check the billing unit.

Both sides are at a scale where the credit absorbs everything: nothing here was charged to a payment method.
