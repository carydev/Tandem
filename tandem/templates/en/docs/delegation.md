# Delegation

Put the goal, background, outputs, write scope, and completion criteria in the task card. Give workers the card path and receive results as files with five-line summaries.
Finish small tasks in one round. When judgment differs, use an R1 proposal → separate R2 critique by another model → R3 response. R2 is read-only. If there is no agreement after three rounds, report the issue as unresolved.
Give R2 only the card path (goal and completion criteria), diff file path, and deliverable path. The delegator saves `git diff` to {{DOCS}}/reports/review/<task>.diff. Do not pass R1 dialogue, reasoning, or self-assessment.
If the wrapper returns `status=stopped`, pass the `STOPPED:` line unchanged. The card author records it per lessons/README.md and decides whether to escalate or redesign.
Workers search relevant paths first and read only the content they need. After working, they run relevant checks and briefly report changes, verification, and risks.

@@if claude-main
Manager → tandem-dispatch → tandem/tools/codex-run.ps1 → Codex lead. The dispatcher only invokes the wrapper and waits for it to complete.
The wrapper appends to runs.jsonl. The dispatcher does not run codex exec directly, poll, read output content, or write logs directly.
@@endif
@@if codex-main
Codex lead → tandem/tools/claude-run.ps1 → Claude worker. The wrapper appends to runs.jsonl.
@@endif
@@if claude-solo
Claude lead → tandem-worker-top/mid/light through the Agent tool. Confirm the specified model and receive outputs as files.
@@endif
@@if codex-solo
Codex lead → .codex/agents/researcher, implementer, reviewer. If a role cannot be called by name, pass its TOML developer_instructions.
codex-run.ps1 is installed but is used only for R2 in a separate session with another model.
@@endif
@@if claude-solo codex-solo
Native subagent calls have no wrapper. The lead appends one line per call to {{DOCS}}/log/runs.jsonl, recording unknown tokens and session as null and the actual decision source in decided_by. Follow log/README.md for the format.
@@endif
