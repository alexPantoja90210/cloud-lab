# Lessons learned

One entry per problem: what happened, root cause, fix, and what is still unresolved.
A problem that was not fixed is recorded as such.

## Template

### YYYY-MM-DD: short title

- **Symptom:**
- **Root cause:**
- **Fix:**
- **Still open:**
- **Source:** (command output, portal page, doc URL with date)

## Entries

### 2026-10-07: Azure free-account terms read from the portal, one point unresolved

- **Symptom:** the portal says services will pause when the free period ends, but the offer terms list 12-month free amounts (B1S / B2pts v2 / B2ats v2 burstable VMs, 750 h/month).
- **Root cause:** the two documents do not say whether the 12-month amounts survive the pause.
- **Fix:** none yet.
- **Still open:** yes. It decides whether Azure compute can be practised after the 200 USD credit window. Decide deliberately before the credit expires, not on the last night.
- **Source:** Azure portal and offer terms, read 7 Oct 2026.

### 2026-10-07: AWS cost view showing 0.00 was net of credits

- **Symptom:** Cost Explorer showed 0.00 USD across 16 services.
- **Root cause:** the default view was net of credits. Unblended cost is the number that shows what the activity would cost without credits.
- **Fix:** set the cost type explicitly (unblended) for any meter or budget used to judge consumption.
- **Source:** AWS Cost Explorer, 7 Oct 2026.

### 2026-10-07: Azure budget alert latency is two separate delays

- **Symptom:** the first budget alert was predicted for the next day, but it arrived within the hour.
- **Root cause:** cost data lag (8-24 h) and the budget evaluation (every 24 h) are separate. If the cost is already recorded, the notification follows the evaluation within about an hour.
- **Fix:** document both delays; never treat a budget as a real-time brake.
- **Source:** Azure budget docs and the observed alert (20:13 UTC, 7 Oct 2026).
