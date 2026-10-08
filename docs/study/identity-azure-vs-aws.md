# Identity: Azure vs AWS, from one lab session

Scope: what was built and observed on 8 Oct 2026 (CLOUD-24), plus general knowledge where marked **[general]**. General-knowledge claims were not tested in this lab and should be checked against the vendor documentation before they are quoted anywhere.

## The same job, two models

The lab did the same thing on both clouds: define a role that can read objects but not write them, let a workload use it without any key, and capture a denial.

| | Azure | AWS |
|---|---|---|
| Unit of permission | Role definition: lists of control-plane `actions` and data-plane `dataActions` | Policy document: `Allow` statements on actions and resource ARNs |
| Who gets it | A separate role assignment: principal + role + scope | The role's trust policy says who may assume it; the permission policy says what it can do |
| Where scope lives | In the assignment (subscription, resource group, resource), inherited downwards | In the policy's resource ARNs, plus the account boundary |
| Keyless access for a workload | User-assigned managed identity attached to the resource; the platform issues tokens | Assumed role: STS issues temporary credentials to a caller the trust policy names |
| Observed denial text | CLI wording: "You do not have the required permissions...", with a generic list of roles that might help | Names the principal, the action, the resource and the missing policy type (`sts:AssumeRole` on the role; `s3:PutObject`, "no identity-based policy allows") |

## Where the models genuinely differ, not just in vocabulary

1. **Who-can-use is stored in different places.** On Azure it is a standalone object (the assignment) at a scope; on AWS the "who" is part of the role itself (the trust policy), and what the caller does afterwards is a second, separate document. Observed here: the intruder was stopped by the trust policy before any permission was evaluated, which is a different door from the one that stopped the write.
2. **Control plane and data plane are separate permission namespaces on Azure.** Observed here: a control-plane action (`containers/read`) was rejected when written as a data action, and `validate` could not catch it. Reading a blob needed a data action even though the identity could already read the account's metadata. On AWS, S3 object access and bucket management share one action namespace (`s3:`).
3. **Denial diagnostics.** The AWS message told us which principal, which action, which resource and which kind of policy was missing; the Azure CLI message did not say which permission was missing. Observed once on each side, so this is an anecdote, not a measurement.
4. **Explicit deny.** **[general]** AWS policies can contain an explicit `Deny` that overrides any `Allow`. Azure RBAC role assignments are additive only; denial there comes from other mechanisms (deny assignments, Azure Policy). Not exercised in this lab.

## Which is easier to audit

The question a fintech reviewer asks is "who can do what to this resource, and how do I prove it?". Reasoning from this lab, not from measurement:

- **"Who has access to this resource group?"** is a direct answer on Azure: list the assignments at that scope and above. The role definition is short and readable. Evidence: the single assignment in this lab.
- **"What can this identity do?"** is a direct answer on AWS for a role like ours: one trust policy and one permission policy. Evidence: both fit in a few lines and were read back from the API.
- **The reverse question on AWS ("who can touch this bucket?")** needs identity policies across principals plus any resource policy. **[general]** AWS provides tooling for this (IAM Access Analyzer, the policy simulator); this lab did not use it, so it cannot say how good it is.
- **Azure's reverse question ("what can this identity do?")** needs its assignments across all scopes. **[general]** The portal's access-check view does this; not used here.

Provisional conclusion: for a small, well-scoped role, both are auditable in minutes. The difference shows up at scale, and the lab did not reach scale. The honest statement for a reviewer is that Azure answers "who has access here" more directly and AWS answers "why was this specific request refused" more directly, and that neither claim has been tested beyond one role per cloud.

## Failure modes found, worth remembering

- Azure: a plausible-looking role definition can be rejected only at apply time; apply layer 0 identity changes in small steps.
- AWS: the CLI caches role credentials by role, not by source profile, so a profile-based "intruder" test can pass for the wrong reason. Test trust policies by calling `sts:AssumeRole` directly.
