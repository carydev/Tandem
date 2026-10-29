<!-- TANDEM:BEGIN -->
## TANDEM — Claude
### Shared work rules
- Think before coding. State assumptions and possible interpretations; ask when something is unclear.
- Keep it simple. Do not add unrequested features, abstractions, or settings.
- Change only what is needed. Do not restructure nearby code or do unrelated cleanup.
- Source: Karpathy rules compiled at github.com/forrestchang/andrej-karpathy-skills.
- Find relevant paths and tables of contents first, then read only the needed sections. Read generated files and large logs only when needed.
- Run commands with long output (build, test, install) through `powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/quiet.ps1 -Command "<command>" -Name <name>`. It prints only the exit code, problem lines, and the last lines; the full output stays in a log file. Search that log if you need more.
- Deliver results in files and a summary of five lines or fewer. Do not copy the full content into the main context.
- Use the top model only when the lead decides to escalate (model-routing.md).

@@if claude-main
### Top rule — talking to the user
These rules have top priority for the main session in every mode. If you break them, that response is a failure.
1. Always answer the user in {{LANG_NAME}}. Explanations, except for code, commands, and proper names, must be in {{LANG_NAME}}.
2. At each key turning point the user needs to know about (a change in direction, another approach after failure, just before risky work, an unexpected result, or a decision), explain it in one or two sentences in {{LANG_NAME}}.
3. Keep completion reports concise and easy to understand: lead with the conclusion and include only what is done and what remains. Provide details, evidence, and logs only when the user asks. Exception: always end interim and completion reports with the run table printed by `tandem/tools/run-table.ps1 -Task <this request's task IDs>`, unchanged (use `-Task none` if nothing was delegated).
Record the work in the topic history: at every interim and completion report run `powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/history.ps1 add -Topic <topic> -Did <done> -Next <next> -Decision <decision|none> [-Files ..] [-Task ..]`, and to continue read only the output of `history.ps1 show -Topic <topic>`. If the history index is not in context and the request continues earlier work, run `history.ps1 index` first. Never read whole history files ({{DOCS}}/history/README.md).
The lead follows {{DOCS}}/lead-charter.md. Delegate Codex execution through the manager and dispatcher.
The dispatcher uses only codex-run.ps1 and does not read the full content or poll.
@@endif
@@if codex-main
Claude is a subagent of the Codex lead. Follow {{DOCS}}/claude-worker.md and the card's scope. Do not replace the lead's decisions or G1/G2.
@@endif
@@if claude-solo
### Top rule — talking to the user
These rules have top priority for the main session in every mode. If you break them, that response is a failure.
1. Always answer the user in {{LANG_NAME}}. Explanations, except for code, commands, and proper names, must be in {{LANG_NAME}}.
2. At each key turning point the user needs to know about (a change in direction, another approach after failure, just before risky work, an unexpected result, or a decision), explain it in one or two sentences in {{LANG_NAME}}.
3. Keep completion reports concise and easy to understand: lead with the conclusion and include only what is done and what remains. Provide details, evidence, and logs only when the user asks. Exception: always end interim and completion reports with the run table printed by `tandem/tools/run-table.ps1 -Task <this request's task IDs>`, unchanged (use `-Task none` if nothing was delegated).
Record the work in the topic history: at every interim and completion report run `powershell -NoProfile -ExecutionPolicy Bypass -File tandem/tools/history.ps1 add -Topic <topic> -Did <done> -Next <next> -Decision <decision|none> [-Files ..] [-Task ..]`, and to continue read only the output of `history.ps1 show -Topic <topic>`. If the history index is not in context and the request continues earlier work, run `history.ps1 index` first. Never read whole history files ({{DOCS}}/history/README.md).
The lead follows {{DOCS}}/lead-charter.md. Call tandem-worker-top/mid/light with the Agent tool.
@@endif
<!-- TANDEM:END -->
