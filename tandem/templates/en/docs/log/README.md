# Run Log

Append one JSON object per run to {{DOCS}}/log/runs.jsonl. Do not change or delete existing lines.
@@if claude-main codex-main
The codex-run.ps1 or claude-run.ps1 execution wrapper writes it. The dispatcher and lead do not write it directly.
@@endif
@@if claude-solo codex-solo
For native subagent calls without a wrapper, the lead appends one line to runs.jsonl per call. Record tokens and session as null when unknown, and always record decided_by.
@@endif

Example:
{"ts":"2026-10-13T09:00:00+09:00","task":"T-12","round":"R1","model":"model ID","effort":"high","result":"ok","escalated_from":null,"workers":null,"out":"{{DOCS}}/reports/work/T-12_v1.md","session":"session ID","tokens":{"input":0,"cached":0,"output":0},"decided_by":"table","note":""}

| Field | Meaning |
|---|---|
| ts | ISO 8601 timestamp |
| task, round | Task ID and R1/R2/R3/single |
| model, effort | Actual model and reasoning effort |
| result | ok/fail/partial/stopped (stopped after the same failure 3 times) |
| escalated_from | Previous model before escalation, or null |
| workers | Number of workers, or null if unknown |
| out | Output path, or null on failure |
| session | CLI session ID, or null if unknown |
| tokens | input/cached/output usage, or null if unknown |
| decided_by | jev/table/human |
| note | Reason for failure or other noteworthy details |

Every five runs, check failures and escalations by model, call counts, and token usage. The lead changes the routing table.
