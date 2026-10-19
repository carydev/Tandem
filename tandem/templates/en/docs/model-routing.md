# Model Routing

Record model IDs under models in tandem/config.json, directly replace unresolved markers in installed files with the same values, then run tandem/tools/manifest.ps1 -Rehash. On update, the installer renders from config, preserving the values in the next version. Do not guess an ID if a model is unavailable.
If `jev.enabled` is false in tandem/config.json, do not call jev.ps1 or mention Jev to the user. Decide with the routing table and record decided_by=table. Otherwise, if a Jev key is available, call tandem/tools/jev.ps1 -Route -Card <card-path> to receive tier and effort. Record decided_by=jev in the log.
For escalation, use tandem/tools/jev.ps1 -Escalate -Card <card-path> -FailNote <failure-summary>. For cross-review, use -NeedCritic -Card <card-path>. If the key is missing, an error occurs, or confidence is low, use the routing table below. Record decided_by=table. Jev proposes model, effort, and the need for cross-review and only advises on escalation; it does not make the final decision or determine G1/G2.
If Jev returns reason `insufficient_credits` or `invalid_key`, decide with the routing table. The main agent tells the user the returned `notice` once in that session, without repeating it for later calls. Subagents and dispatchers pass the `notice` unchanged to the main agent.

@@if claude-main
| Role | Model | Default effort |
|---|---|---|
| Claude lead | {{CLAUDE_LEAD}} | Account setting |
| Manager | {{CLAUDE_MANAGER}} | One tier below the lead by default |
| Dispatcher | {{CLAUDE_DISPATCH}} | Low |
| Cross-reviewer | {{CLAUDE_CRITIC}} | Per task |
| Codex lead | {{MODEL_MID}} | high |
| Codex worker | {{MODEL_LIGHT}} | medium |
| Codex escalation | {{MODEL_TOP}} | xhigh (escalation only) |
Use codex-run.ps1 for Codex calls. R2 uses the mid tier in a separate read-only session.
@@endif
@@if codex-main
| Role | Model | Default effort |
|---|---|---|
| Codex lead | {{MODEL_TOP}} | Account setting |
| Claude implementation | {{CLAUDE_MID}} | Per task |
| Claude light worker | {{CLAUDE_LIGHT}} | Per task |
| Claude escalation | {{CLAUDE_TOP}} | Escalation only |
Use claude-run.ps1 for Claude calls.
@@endif
@@if claude-solo
| Role | Model |
|---|---|
| Lead | {{CLAUDE_LEAD}} |
| Escalation worker (escalation only) | {{CLAUDE_TOP}} |
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
| Review | {{MODEL_MID}} | high (read-only) |
| Escalation | {{MODEL_TOP}} | xhigh (escalation only) |
Follow the role definitions in .codex/agents.
@@endif

## Top-model policy

No role below the lead uses the top tier (Claude `claude_top`, Codex `codex_top`) by default. Use it only when the user directly specifies it on that card (`decided_by=human`), or when the same card has failed once at the mid tier (`STOPPED:` or unmet completion criteria) and the lead finds **insufficient model capability** to be the cause. Ambiguous specifications, environment problems, and scope errors require a card revision.
Each card permits one escalation and one R1 rerun at the higher tier. Only the lead decides. Record `escalated_from` and `reason` in `runs.jsonl`, plus one line at the top of the card and one at the top of the deliverable. In wrapper modes, never run the top tier without `-EscalatedFrom` and `-Reason`; in native modes, the lead writes the same two fields directly to `runs.jsonl`. Jev does not choose the top tier; `-Escalate` is advisory and does not replace the eligibility conditions.
For the claude-main manager (tandem-manager), `claude_manager`, one tier below the lead, is the default. If the user specifies the top tier or the lead decides it is needed, the lead sets model on the Agent call and tells the user in one line. The manager only proposes with a reason. R2 adversarial review uses the mid tier in a separate read-only session from R1 (another model when possible). Only for hard-to-reverse decision reviews under `operating-model.md` may the lead approve the top tier and record the reason.
