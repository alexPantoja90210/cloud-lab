# Google Cloud terms and guardrails (CLOUD-39, 20 Oct 2026)

Own free-trial billing account opened 19 Oct 2026. Terms below were read on 20 Oct 2026 from Google's public
page "Free cloud features" (docs.cloud.google.com/free/docs/free-cloud-features), not from the Billing console
(the operator could not find the trial-end link there). They can change; re-read before relying on them.

## Account facts (operator, console)

- Currency of the billing account: MXN (confirmed by the operator on 20 Oct). The credit shows as $5,344 MXN, 0 used, expires 18 Jan 2027.
- The account was upgraded to a full (paid) account on 19 Oct (email at 21:37). How it happened is not confirmed.
- Budget alerts: alert-20-mxn and alert-90-mxn (50/90/100 %). They only notify; they do not stop spending.
- Cards: physical and virtual card blocked at the bank on 20 Oct (bank confirmation pending, 21 Oct). The 850 MXN charge at opening was an authorization hold, expected to be released in about 10 days; re-check on 29 Oct.

## What happens when the trial ends (public terms)

- A non-upgraded trial closes when the $300 credit is spent or 90 days pass from signup. Then billing is disabled, running resources stop, and after a 30-day grace period trial resources are permanently deleted.
- If the account is upgraded to paid (this account), the trial does not auto-close: resources keep running without interruption.
- After an upgrade the remaining credit still applies, but it must be used within the original 90 days from signup (here, until 18 Jan 2027). Usage beyond the credit, Free Tier limits or products outside the trial is charged to the payment method.

## Consequence for this lab

- The protection "the trial stops by itself when the credit ends" no longer applies. Because the account is paid, spending past the credit would go to the card; the card block at the bank is the real guardrail, and budgets are only alerts.
- Not verified: what Google does when a charge to a blocked card fails (most likely suspends billing and the resources). Not tested.
- Safe practice: nothing left running between sessions, teardown verified empty, costs read the next day.

## What the trial excludes or limits (public terms)

- The credit cannot pay for Gemini API costs in AI Studio, nor for generative AI partner models offered as managed APIs.
- On a non-billable trial account: no GPUs on VMs, no Marketplace, no quota increases, no Windows Server VMs, no VMware Engine. (Paid accounts regain these.)
- Cryptocurrency mining is prohibited; product access may be limited to prevent abuse.
- Free Tier is separate from the credit: for example one e2-micro per month in us-west1, us-central1 or us-east1; Cloud Storage Free Tier only in us-east1, us-west1 and us-central1 (the drill bucket used us-east1).

## Open

- Billing console path for the trial-end text: not found by the operator.
- Behavior of a failed charge on a blocked card: not verified.
