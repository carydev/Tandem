# Delegation

Put the goal, background, outputs, write scope, and completion criteria in the task card. Give workers the card path and receive results as files with five-line summaries.
Finish small tasks in one round. When judgment differs, use an R1 proposal → R2 adversarial review at the mid tier in a separate read-only session (another model when possible) → R3 response. If there is no agreement after three rounds, report the issue as unresolved.
R3, retries, and reruns after rejection resume the R1 session for caching. R2 and escalations start new sessions.
Give R2 only the card path (goal and completion criteria), diff file path, and deliverable path. Do not pass R1 dialogue, reasoning, or self-assessment.
@@if claude-main codex-main
On an R2 call, the wrapper saves the changes (including new files) with `tandem/tools/diff.ps1` and passes the path.
@@endif
@@if claude-solo codex-solo
The lead runs `tandem/tools/diff.ps1 -Task <ID>` and gives the resulting path to the reviewer.
@@endif
If the wrapper returns `status=stopped`, pass the `STOPPED:` line unchanged. The card author records it per lessons/README.md. Only the lead decides escalation under the policy in model-routing.md.
Workers search relevant paths first and read only the content they need. After working, they run relevant checks and briefly report changes, verification, and risks.

@@if claude-main
Manager → tandem-dispatch → tandem/tools/codex-run.ps1 → Codex lead. The dispatcher only invokes the wrapper and waits for it to complete.
The wrapper appends to runs.jsonl. The dispatcher does not run codex exec directly, poll, read output content, or write logs directly.
@@endif
@@if codex-main
Codex lead → tandem/tools/claude-run.ps1 → Claude worker. The wrapper appends to runs.jsonl. The top model (`claude_top`) runs only when the lead passes `-EscalatedFrom <ID> -Reason <one line>` (or `-DecidedBy human -Reason` for a user choice).
@@endif
@@if claude-solo
Claude lead → tandem-worker-top/mid/light through the Agent tool. Confirm the specified model and receive outputs as files.
@@endif
@@if codex-solo
Codex lead → .codex/agents/researcher, implementer, reviewer. If a role cannot be called by name, pass its TOML developer_instructions.
codex-run.ps1 is installed but is used only for R2 at the mid tier in a separate read-only session.
@@endif
@@if claude-solo codex-solo
Native subagent calls have no wrapper. The lead appends one line per call to {{DOCS}}/log/runs.jsonl, recording unknown tokens and session as null and the actual decision source in decided_by. Also record the agent name, card title, and elapsed time (agent, title, duration_s). Follow log/README.md for the format.
@@endif

## R2 Verdicts and R3 Responses

R2 numbers each finding (F1, F2, ...) and gives it exactly one verdict. `confirmed` is a defect with evidence (path:line or location in the deliverable) and a severity (high/medium/low); `needs_validation` is a finding whose evidence could not be verified (no severity; `unknown=` names the fact); `rejected` is a candidate dismissed during review (`reason=`). Provide at least three confirmed + needs_validation findings.
The lead checks the format with `tandem/tools/review-check.ps1 -Review <R2 path>`. `status=fail` means there are no verdict lines, so request R2 again. The lead reads `warn` lines and decides.
@@if claude-main codex-main
After an R2 call, the wrapper runs the same check, adds a `review=` line to the summary, and records `findings` in runs.jsonl.
@@endif
Someone other than the finder verifies needs_validation items: the lead checks directly or assigns a separate verification task. The lead then rules confirmed or rejected.
R3 answers every confirmed and needs_validation item in one line: `- F1 fixed|disputed|deferred <one line>`. `review-check.ps1 -Review <R2> -Response <R3>` reports missing IDs.
Reject the work if a confirmed high finding is not fixed. The lead rules on disputed items; anything still open after three rounds is recorded as an open issue.
