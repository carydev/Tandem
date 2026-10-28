# Run Log

Append one JSON object per run to {{DOCS}}/log/runs.jsonl. Do not change or delete existing lines.
@@if claude-main codex-main
The codex-run.ps1 or claude-run.ps1 execution wrapper writes it. The dispatcher and lead do not write it directly.
@@endif
@@if claude-solo codex-solo
For native subagent calls without a wrapper, the lead appends one line to runs.jsonl per call. Record tokens and session as null when unknown, and always record decided_by. Record resumed and thread_total when available.
Set `kind` to native, `agent` to the subagent name, `title` to the card title, and `duration_s` to elapsed seconds. For a Claude Agent result, log total_tokens as `tokens: {"total": N}` and duration_ms divided by 1000. For a Codex subagent, log its session (thread ID); the run table then reads its tokens from the Codex session file.
Record `escalated_from` and `reason` separately, using null when absent.
@@endif

Example:
{"ts":"2026-10-13T09:00:00+09:00","kind":"codex-run","agent":"codex-lead","title":"Fix login error","duration_s":312,"task":"T-12","round":"R1","model":"model ID","effort":"high","result":"ok","escalated_from":null,"reason":null,"workers":null,"out":"{{DOCS}}/reports/work/T-12_v1.md","session":"session ID","resumed":false,"tokens":{"input":0,"cached":0,"output":0},"thread_total":{"input":0,"cached":0,"output":0},"findings":null,"decided_by":"table","note":""}

| Field | Meaning |
|---|---|
| ts | ISO 8601 timestamp |
| kind | codex-run/claude-run/batch/native |
| agent | Agent that ran. Wrapper defaults codex-lead, codex-reviewer, claude-worker, claude-reviewer, codex-batch; null if unknown |
| title | Card title from its first line, or null |
| duration_s | Elapsed seconds, or null if unknown |
| task, round | Task ID and R1/R2/R3/single |
| model, effort | Actual model and reasoning effort |
| result | ok/fail/partial/stopped (stopped after the same failure 3 times) |
| escalated_from | Previous model before escalation, or null. Required for a top model unless decided_by=human |
| reason | Top-model use or escalation reason, or null |
| workers | Number of workers, or null if unknown |
| out | Output path, or null on failure |
| session | CLI session ID, or null if unknown |
| tokens | input/cached/output usage for this call ({"total": N} allowed for native calls), or null if unknown |
| resumed | Whether the prior session was resumed |
| thread_total | Cumulative input/cached/output for the session, or null if unknown |
| findings | R2 verdict counts {confirmed, needs_validation, rejected}; null when not R2 or unknown |
| decided_by | jev/table/human |
| note | Reason for failure or other noteworthy details |

`tandem/tools/run-table.ps1 -Task <ID>` builds the report run table from this log (`-Since today|2h|all`, `-Max 10`). Columns missing from older records show as —.
Every five runs, check failures and escalations by model, call counts, and token usage. The lead changes the routing table.
