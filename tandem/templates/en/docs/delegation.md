# Delegation

Put the goal, background, outputs, write scope, and completion criteria in the task card. Give workers the card path and receive results as files with five-line summaries.
Finish small tasks in one round. When judgment differs, use an R1 proposal → R2 adversarial review at the mid tier in a separate read-only session (another model when possible) → R3 response. If there is no agreement after three rounds, report the issue as unresolved.
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
Native subagent calls have no wrapper. The lead appends one line per call to {{DOCS}}/log/runs.jsonl, recording unknown tokens and session as null and the actual decision source in decided_by. Follow log/README.md for the format.
@@endif
