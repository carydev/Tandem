# Model Routing

Record model IDs under models in tandem/config.json, directly replace unresolved markers in installed files with the same values, then run tandem/tools/manifest.ps1 -Rehash. On update, the installer renders from config, preserving the values in the next version. Do not guess an ID if a model is unavailable.
If `jev.enabled` is false in tandem/config.json, do not call jev.ps1 or mention Jev to the user. Decide with the routing table and record decided_by=table. Otherwise, if a Jev key is available, call tandem/tools/jev.ps1 -Route -Card <card-path> to receive tier and effort. Record decided_by=jev in the log.
For escalation, use tandem/tools/jev.ps1 -Escalate -Card <card-path> -FailNote <failure-summary>. For cross-review, use -NeedCritic -Card <card-path>. If the key is missing, an error occurs, or confidence is low, use the routing table below. Record decided_by=table. Jev determines only model and effort, escalation, and the need for cross-review; it does not make the final decision or determine G1/G2.
If Jev returns reason `insufficient_credits` or `invalid_key`, decide with the routing table. The main agent tells the user the returned `notice` once in that session, without repeating it for later calls. Subagents and dispatchers pass the `notice` unchanged to the main agent.

@@if claude-main
| Role | Model | Default effort |
|---|---|---|
| Claude lead | {{CLAUDE_LEAD}} | Account setting |
| Manager | {{CLAUDE_MANAGER}} | Per task |
| Dispatcher | {{CLAUDE_DISPATCH}} | Low |
| Cross-reviewer | {{CLAUDE_CRITIC}} | Per task |
| Codex lead | {{MODEL_MID}} | high |
| Codex worker | {{MODEL_LIGHT}} | medium |
| Codex escalation | {{MODEL_TOP}} | xhigh |
Use codex-run.ps1 for Codex calls. R2 uses a different model in a separate read-only session.
@@endif
@@if codex-main
| Role | Model | Default effort |
|---|---|---|
| Codex lead | {{MODEL_TOP}} | Account setting |
| Claude implementation | {{CLAUDE_MID}} | Per task |
| Claude light worker | {{CLAUDE_LIGHT}} | Per task |
| Claude escalation | {{CLAUDE_TOP}} | Per task |
Use claude-run.ps1 for Claude calls.
@@endif
@@if claude-solo
| Role | Model |
|---|---|
| Lead | {{CLAUDE_LEAD}} |
| Top worker | {{CLAUDE_TOP}} |
| Mid worker | {{CLAUDE_MID}} |
| Light worker | {{CLAUDE_LIGHT}} |
Call the model-assigned tandem-worker-top/mid/light through the Agent tool.
@@endif
@@if codex-solo
| Role | Model | Effort |
|---|---|---|
| Lead | {{MODEL_TOP}} | Account setting |
| Implementation worker | {{MODEL_MID}} | high |
| Light worker | {{MODEL_LIGHT}} | medium |
Follow the role definitions in .codex/agents.
@@endif

Start with light extraction and summarization. Use the middle tier with high effort for design decisions, and escalate genuinely difficult problems after an actual failure. Long autonomous work or an explicit instruction also warrants escalation.
Do not move to a top model without a concrete reason. If Jev is unavailable, decide from the routing table and failure record. Record the reason for escalation and previous model in the output and log.
Perform the R2 critique in a separate session with a different model from R1. If an issue remains after three rounds, report it as unresolved.
