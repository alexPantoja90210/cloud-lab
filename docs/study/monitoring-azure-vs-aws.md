# Monitoring, Azure vs AWS (CLOUD-29, read only, 2 Nov 2026)

**Nothing in this note was built.** The Azure credit expired before the monitoring exercise was started, and the AWS
half has not been built yet. Everything below comes from the vendors' documentation, read on 2 Nov 2026, and from
prices read earlier in the lab. There are no measurements of my own: no alert was fired, no mail was waited for, no
query was run, and no delay was recorded. Where the ticket asks for those, this note says "not measured".

## How each cloud models the pieces (from documentation)

| Piece | Azure | AWS |
|---|---|---|
| Numbers over time (metrics) | Platform metrics are collected automatically for every resource | CloudWatch metrics, published by each service |
| A rule on a metric | Alert rule: the resources, the signal and the condition; one alert per resource | CloudWatch alarm on one metric, with a period, evaluation periods and "datapoints to alarm" (for example 2 of 3) |
| Who gets told | Action group: email, SMS, push, webhook, Function, Logic App, ITSM, Event Hubs, runbook | An SNS topic chosen per alarm state; email goes through an SNS subscription that the recipient confirms |
| States | Fired, then resolved; plus a manual response (New, Acknowledged, Closed) | `OK`, `ALARM`, `INSUFFICIENT_DATA` |
| Rule on log content | Log search alert: a Log Analytics query run at a set frequency (and a "simple" variant that evaluates each row) | Metric filter on a log group turned into a metric, then an alarm (not read in detail here) |
| Logs of a resource | Resource logs are off by default; a diagnostic setting sends them to Log Analytics, a storage account, Event Hubs or a partner | Service-specific: each service writes to a CloudWatch Logs log group when enabled |
| Query language | KQL in Log Analytics | Logs Insights (named in the ticket; its syntax was not read for this note) |
| Who did what (audit) | Activity log, collected automatically; a diagnostic setting exports it | CloudTrail Event history: management events of the last 90 days, on by default, free to view; a trail is needed for longer retention or for data events |

## Differences worth keeping

- **Defaults.** On Azure, platform metrics and the activity log are on without any setup, but resource logs need a
  diagnostic setting on each resource (up to five per resource, one destination of each type per setting). On AWS,
  the audit trail of the last 90 days of management events is on from account creation.
- **Alert delay is part of the design.** Azure documents it: for a metric alert checked every 5 minutes or more, the
  notification arrives between one and two times the frequency (15 to 30 minutes for a 15-minute frequency). A metric
  alert resolves after three consecutive checks without the condition. Diagnostic data should arrive within about
  90 minutes. For CloudWatch, how long it takes depends on the alarm period and the evaluation settings; I did not
  find a figure to quote. CloudTrail delivery to a bucket averages about 5 minutes, not guaranteed. The ticket's
  planned measurement (condition to mail, against the budget-alert delay of CLOUD-22) was **not measured**.
- **Two steps before a mail.** Both clouds separate the rule from the destination of the message (action group on
  Azure, SNS topic on AWS). On AWS the email also needs a confirmation by the recipient before any alarm mail arrives.
- **Alert instances.** Azure keeps fired alerts for 30 days and treats them as read-only; configuration changes only
  affect future alerts.

## Cost shape (prices read in the lab, not reconfirmed on 2 Nov)

- Azure Log Analytics, East US 2, read on 24 Oct 2026 from the retail price list: retention 0.12 USD per GB-month;
  "Data Analyzed" 2.30 USD per GB (the Analytics Logs and Standard rows); ingestion showed 0.0 in the filtered output, and the
  paid ingestion tier was **not seen**, so no ingestion price is quoted here.
- AWS, as written in the ticket on 22 Sep 2026 and not reconfirmed: retention 0.03 USD per GB-month, ingestion above
  5 GB at 0.50 USD per GB.
- CloudTrail Event history: no CloudTrail charge to view it. One copy of ongoing management events delivered to S3 is
  free of CloudTrail charge, with S3 storage charged.
- What logging costs per day in the bill was **not read**, because no logging was enabled.

## What was built, what by Terraform, what was only read

- Built by hand: nothing.
- Built by Terraform: nothing.
- Only read: all of the above, from documentation.

## Not done

Everything the ticket asks for: an alert fired on a real condition on each cloud and the delay recorded; a query that
finds a real event from an earlier domain; the cost of logging read in the portals and compared with the CLI; the
Terraform twin of each. Azure cannot be built any more (subscription disabled). AWS can, and this note should be
updated from what that session actually produces.

## The operator's reading

*(To be written by the operator, in his own words.)*

## Sources (read 2 Nov 2026)

- Azure Monitor alerts overview: https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-overview
- Diagnostic settings in Azure Monitor: https://learn.microsoft.com/EN-US/AZURE/azure-monitor/platform/diagnostic-settings
- CloudWatch alarm on a static threshold: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ConsoleAlarms.html
- How CloudTrail works: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/how-cloudtrail-works.html
