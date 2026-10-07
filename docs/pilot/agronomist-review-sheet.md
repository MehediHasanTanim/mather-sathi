# Agronomist blind review sheet

Review at least 100 diagnoses **without seeing the app's answer first**. Photos come from `backups/`/`contrib/` objects of consenting pilot users, or are collected by the field team.

| # | Photo file | Crop | True disease (agronomist, from the KB list or "other/none") | Confidence in own call (high/medium/low) | App's answer (filled in after) | Match? | Advice safe and right? (Y/N + note) | Medicine and dose correct? (Y/N/none shown) |
|---|---|---|---|---|---|---|---|---|

Rules: any "N" in the last column is a **safety incident**: follow the incident procedure in `docs/release/ops-runbook.md` (§8) the same day. Compute accuracy per crop and the observed accuracy per confidence bucket; feed the true labels back into `tools/eval` as the next held-out set.
