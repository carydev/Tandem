# Output Folders

| Folder | Contents |
|---|---|
| work/ | Implementation outputs |
| work/parts/ | Partial outputs from workers |
| critique/ | Separate R2 critiques |
| review/ | Conditional cross-reviews |
| setup/ | Installation and adaptation reports |

@@if claude-main
The Codex lead writes to work/. The Claude manager reviews the summary first and sends only a synthesis to the lead.
@@endif
@@if codex-main
The Claude worker writes to work/. The Codex lead reviews the summary first.
@@endif
@@if claude-solo
The Claude worker writes to work/. The Claude lead reviews the summary first.
@@endif
@@if codex-solo
The Codex worker writes to work/. The Codex lead reviews the summary first.
@@endif

Each output states the task ID, author role and model, round, conclusion, evidence and sources, unresolved issues, and verification results.
Keep the opening summary to five lines or fewer. R2 writes each finding as a verdict line `- F1 [confirmed|needs_validation|rejected]`: confirmed requires evidence and severity, needs_validation names the unverified fact without a severity, rejected gives the reason. At least three confirmed + needs_validation. Format: delegation.md, "R2 Verdicts and R3 Responses".
